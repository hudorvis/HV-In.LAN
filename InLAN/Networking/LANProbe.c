#include "LANProbe.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

struct LANCancelFlag { atomic_bool cancelled; };

LANCancelFlag *lan_cancel_create(void) {
    LANCancelFlag *flag = malloc(sizeof(*flag));
    if (flag) atomic_init(&flag->cancelled, false);
    return flag;
}
void lan_cancel_set(LANCancelFlag *flag) { atomic_store(&flag->cancelled, true); }
bool lan_cancelled(const LANCancelFlag *flag) { return atomic_load(&flag->cancelled); }
void lan_cancel_destroy(LANCancelFlag *flag) { free(flag); }

static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000.0 + t.tv_nsec / 1000000.0;
}

static struct sockaddr_in endpoint(uint32_t ip, uint16_t port) {
    struct sockaddr_in addr = {0};
#ifdef __APPLE__
    addr.sin_len = sizeof(addr);
#endif
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(ip);
    addr.sin_port = htons(port);
    return addr;
}

static int scoped_socket(int type, int protocol, uint32_t local_ip, uint32_t index) {
    int fd = socket(AF_INET, type, protocol);
    if (fd < 0) return -1;
    struct sockaddr_in local = endpoint(local_ip, 0);
    int flags = fcntl(fd, F_GETFL, 0);
    bool ok = flags >= 0 && fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0;
#ifdef __APPLE__
    if (index == 0) { close(fd); errno = ENXIO; return -1; }
    ok = ok && setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &index, sizeof(index)) == 0;
#else
    (void)index;
#endif
    if (ok && bind(fd, (struct sockaddr *)&local, sizeof(local)) == 0) return fd;
    int saved = errno;
    close(fd);
    errno = saved;
    return -1;
}

// A short polling interval lets cancellation release all descriptors promptly.
static int wait_ready(struct pollfd *fds, nfds_t count, double deadline, const LANCancelFlag *flag) {
    while (!lan_cancelled(flag)) {
        double remaining = deadline - now_ms();
        if (remaining <= 0) break;
        int timeout = remaining > 40 ? 40 : (int)remaining + 1;
        int n = poll(fds, count, timeout);
        if (n > 0 || (n < 0 && errno != EINTR)) return n;
    }
    return 0;
}

static uint16_t checksum(const uint8_t *data, size_t length) {
    uint32_t sum = 0;
    for (size_t i = 0; i < length; i += 2) {
        sum += (uint16_t)data[i] << 8;
        if (i + 1 < length) sum += data[i + 1];
    }
    while (sum >> 16) sum = (sum & 0xffff) + (sum >> 16);
    return (uint16_t)~sum;
}

static bool denied(int error) { return error == EACCES || error == EPERM; }
static bool interface_lost(int error) {
    return error == EADDRNOTAVAIL || error == ENETDOWN || error == ENETUNREACH || error == ENXIO;
}

// Datagram sockets may rewrite the identifier. The source address is checked by the caller.
static bool matches_echo(const uint8_t *buf, size_t n, const uint8_t *request, size_t length) {
    if (!n || length < 8) return false;
    size_t offset = 0;
    if ((buf[0] >> 4) == 4) {
        offset = (buf[0] & 15u) * 4u;
        if (offset < 20 || n < offset || buf[9] != IPPROTO_ICMP) return false;
    }
    return n >= offset + length && buf[offset] == 0 && buf[offset + 1] == 0 &&
           memcmp(buf + offset + 6, request + 6, length - 6) == 0;
}

static void echo_probe(uint32_t ip, uint32_t local_ip, uint32_t index, const LANCancelFlag *flag,
                       LANProbeResult *result) {
    int fd = scoped_socket(SOCK_DGRAM, IPPROTO_ICMP, local_ip, index);
    if (fd < 0) {
        // A platform may disallow datagram ICMP while permitting TCP.
        result->local_error = interface_lost(errno);
        return;
    }
    uint8_t packet[24] = {8};
    arc4random_buf(packet + 4, sizeof(packet) - 4);
    uint16_t sum = htons(checksum(packet, sizeof(packet)));
    memcpy(packet + 2, &sum, sizeof(sum));
    struct sockaddr_in dest = endpoint(ip, 0);
    double start = now_ms();
    ssize_t sent = sendto(fd, packet, sizeof(packet), 0, (struct sockaddr *)&dest, sizeof(dest));
    if (sent == (ssize_t)sizeof(packet)) {
        result->echo_sent = true;
        struct pollfd pfd = {.fd = fd, .events = POLLIN};
        while (wait_ready(&pfd, 1, start + 450, flag) > 0) {
            uint8_t buf[2048];
            struct sockaddr_in from = {0};
            socklen_t from_len = sizeof(from);
            ssize_t n = recvfrom(fd, buf, sizeof(buf), 0, (struct sockaddr *)&from, &from_len);
            if (n < 0) {
                if (errno == EINTR || errno == EAGAIN) continue;
                result->access_denied = denied(errno);
                result->local_error = interface_lost(errno);
                break;
            }
            if (n == 0 || from.sin_family != AF_INET || from.sin_addr.s_addr != dest.sin_addr.s_addr) continue;
            if (matches_echo(buf, (size_t)n, packet, sizeof(packet))) {
                result->echo_ms = now_ms() - start;
                break;
            }
        }
    } else {
        result->access_denied = denied(errno);
        result->local_error = interface_lost(errno);
    }
    close(fd);
}

static void tcp_outcome(LANProbeResult *result, uint16_t port, int error) {
    if (error == 0 || error == ECONNREFUSED || error == EHOSTUNREACH || error == EHOSTDOWN || error == ETIMEDOUT)
        result->tcp_checked = true;
    if (error == 0) result->open_port = port;
    else if (error == ECONNREFUSED) result->tcp_refused = true;
    else if (denied(error)) result->access_denied = true;
    else if (interface_lost(error)) result->local_error = true;
}

static void tcp_batch(const uint16_t *ports, size_t count, uint32_t ip, uint32_t local_ip,
                      uint32_t index, const LANCancelFlag *flag, LANProbeResult *result) {
    struct pollfd fds[3];
    size_t pending = 0;
    double deadline = now_ms() + 300;
    for (size_t i = 0; i < count; ++i) {
        int fd = scoped_socket(SOCK_STREAM, IPPROTO_TCP, local_ip, index);
        fds[i] = (struct pollfd){.fd = fd, .events = POLLOUT};
        if (fd < 0) {
            if (denied(errno)) result->access_denied = true;
            else result->local_error = true;
            continue;
        }
        struct sockaddr_in dest = endpoint(ip, ports[i]);
        int rc = connect(fd, (struct sockaddr *)&dest, sizeof(dest));
        if (rc < 0 && (errno == EINPROGRESS || errno == EINTR)) {
            result->tcp_checked = true;
            ++pending;
            continue;
        }
        tcp_outcome(result, ports[i], rc == 0 ? 0 : errno);
        close(fd);
        fds[i].fd = -1;
    }
    while (pending && !result->open_port &&
           wait_ready(fds, count, deadline, flag) > 0) {
        for (size_t i = 0; i < count; ++i) {
            if (fds[i].fd < 0 || !fds[i].revents) continue;
            int error = 0;
            socklen_t length = sizeof(error);
            if (!(fds[i].revents & POLLNVAL) && getsockopt(fds[i].fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0) {
                if (error == 0) {
                    struct sockaddr_in peer;
                    socklen_t peer_len = sizeof(peer);
                    if (getpeername(fds[i].fd, (struct sockaddr *)&peer, &peer_len) < 0) error = errno;
                }
                tcp_outcome(result, ports[i], error);
            } else {
                result->local_error = true;
            }
            close(fds[i].fd);
            fds[i].fd = -1;
            --pending;
        }
    }
    for (size_t i = 0; i < count; ++i) if (fds[i].fd >= 0) close(fds[i].fd);
}

static void tcp_fallback(const uint16_t *ports, size_t count, uint32_t address, uint32_t local_address,
                         uint32_t interface_index, const LANCancelFlag *flag, LANProbeResult *result) {
    for (size_t i = 0; i < count && !lan_cancelled(flag); i += 3) {
        size_t batch_size = count - i > 3 ? 3 : count - i;
        tcp_batch(ports + i, batch_size, address, local_address, interface_index, flag, result);
        if (result->open_port || result->access_denied || result->local_error) break;
    }
}

LANProbeResult lan_probe(uint32_t address, uint32_t local_address, uint32_t interface_index,
                         uint16_t preferred_port, const LANCancelFlag *flag) {
    LANProbeResult result = {.echo_ms = -1};
    if (lan_cancelled(flag)) return result;
    echo_probe(address, local_address, interface_index, flag, &result);
    if (result.echo_ms >= 0 || result.local_error) return result;
    // An ICMP-specific restriction is not proof that TCP or Local Network access is denied.
    result.access_denied = false;

    const uint16_t common[] = {80, 443, 22, 445, 554, 8000, 8080, 9100, 62078};
    uint16_t ports[10];
    size_t count = 0;
    if (preferred_port) ports[count++] = preferred_port;
    for (size_t i = 0; i < sizeof(common)/sizeof(common[0]); ++i)
        if (common[i] != preferred_port) ports[count++] = common[i];
    tcp_fallback(ports, count, address, local_address, interface_index, flag, &result);
    return result;
}
