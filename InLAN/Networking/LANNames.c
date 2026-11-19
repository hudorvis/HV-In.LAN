#include "LANNames.h"
#include <arpa/inet.h>
#include <dns_sd.h>
#include <errno.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

typedef struct {
    bool done;
    char *host;
    size_t capacity;
    uint16_t port;
    uint32_t *addresses;
    size_t count;
    size_t limit;
} Lookup;

static double time_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

static void process(DNSServiceRef ref, Lookup *out, double deadline, const LANCancelFlag *flag) {
    struct pollfd fd = {.fd = DNSServiceRefSockFD(ref), .events = POLLIN};
    while (fd.fd >= 0 && !out->done && !lan_cancelled(flag) && time_seconds() < deadline) {
        int n = poll(&fd, 1, 40);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 || (n > 0 && !(fd.revents & POLLIN))) break;
        if (n > 0 && DNSServiceProcessResult(ref) != kDNSServiceErr_NoError) break;
    }
    DNSServiceRefDeallocate(ref);
}

static void DNSSD_API service_reply(DNSServiceRef ref, DNSServiceFlags flags, uint32_t index,
    DNSServiceErrorType error, const char *fullname, const char *host, uint16_t port,
    uint16_t txt_len, const unsigned char *txt, void *context) {
    (void)ref; (void)flags; (void)index; (void)fullname; (void)txt_len; (void)txt;
    Lookup *out = context;
    out->done = true;
    if (error || !host || strlen(host) >= out->capacity) return;
    memcpy(out->host, host, strlen(host) + 1);
    out->port = ntohs(port);
}

static void DNSSD_API address_reply(DNSServiceRef ref, DNSServiceFlags flags, uint32_t index,
    DNSServiceErrorType error, const char *host, const struct sockaddr *addr, uint32_t ttl, void *context) {
    (void)ref; (void)index; (void)host;
    Lookup *out = context;
    if (!error && addr && addr->sa_family == AF_INET) {
        uint32_t ip = ntohl(((const struct sockaddr_in *)addr)->sin_addr.s_addr);
        size_t i = 0;
        while (i < out->count && out->addresses[i] != ip) ++i;
        if ((flags & kDNSServiceFlagsAdd) && ttl != 0) {
            if (i == out->count && i < out->limit) out->addresses[out->count++] = ip;
        } else if (i < out->count) {
            out->addresses[i] = out->addresses[--out->count];
        }
    }
    out->done = error || !(flags & kDNSServiceFlagsMoreComing) || out->count >= out->limit;
}

size_t lan_resolve_service(const char *name, const char *type, const char *domain, uint32_t index,
                           char *hostname, size_t capacity, uint16_t *port,
                           uint32_t *addresses, size_t limit, const LANCancelFlag *flag) {
    if (!index || !capacity || !limit || lan_cancelled(flag)) return 0;
    hostname[0] = '\0';
    *port = 0;
    Lookup out = {.host = hostname, .capacity = capacity, .addresses = addresses, .limit = limit};
    DNSServiceRef ref = NULL;
    double deadline = time_seconds() + 2.0;
    if (DNSServiceResolve(&ref, 0, index, name, type, domain, service_reply, &out)) return 0;
    process(ref, &out, deadline, flag);
    if (!out.port || !hostname[0] || lan_cancelled(flag)) return 0;
    out.done = false;
    if (DNSServiceGetAddrInfo(&ref, 0, index, kDNSServiceProtocol_IPv4, hostname, address_reply, &out)) return 0;
    process(ref, &out, deadline, flag);
    *port = out.port;
    return out.count;
}

static void DNSSD_API ptr_reply(DNSServiceRef ref, DNSServiceFlags flags, uint32_t index,
    DNSServiceErrorType error, const char *fullname, uint16_t type, uint16_t rrclass,
    uint16_t length, const void *data, uint32_t ttl, void *context) {
    (void)ref; (void)index; (void)fullname;
    Lookup *out = context;
    out->done = true;
    if (error || !ttl || !(flags & kDNSServiceFlagsAdd) || type != kDNSServiceType_PTR ||
        rrclass != kDNSServiceClass_IN || !data) return;
    // DNS-SD supplies uncompressed, length-prefixed labels in PTR RDATA.
    const uint8_t *wire = data;
    size_t pos = 0, written = 0;
    while (pos < length && wire[pos]) {
        size_t n = wire[pos++];
        if (n > 63 || pos + n > length || written + n + 1 >= out->capacity) return;
        for (size_t i = 0; i < n; ++i) {
            if (wire[pos + i] < 32 || wire[pos + i] == 127) return;
        }
        if (written) out->host[written++] = '.';
        memcpy(out->host + written, wire + pos, n);
        pos += n;
        written += n;
    }
    if (pos + 1 == length && written) {
        out->host[written] = '\0';
        out->count = 1;
    }
}

bool lan_reverse_name(uint32_t ip, uint32_t index, char *name, size_t capacity, const LANCancelFlag *flag) {
    if (!index || !capacity || lan_cancelled(flag)) return false;
    char query[64];
    snprintf(query, sizeof(query), "%u.%u.%u.%u.in-addr.arpa.",
             ip & 255, (ip >> 8) & 255, (ip >> 16) & 255, ip >> 24);
    DNSServiceRef ref = NULL;
    Lookup out = {.host = name, .capacity = capacity};
    if (DNSServiceQueryRecord(&ref, 0, index, query, kDNSServiceType_PTR, kDNSServiceClass_IN, ptr_reply, &out)) return false;
    process(ref, &out, time_seconds() + 1.25, flag);
    return out.count != 0;
}
