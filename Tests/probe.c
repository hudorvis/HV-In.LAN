// Exercise the production socket implementation against ephemeral loopback endpoints only.
#include "../InLAN/Networking/LANProbe.c"
#include <assert.h>
#include <net/if.h>
#include <stdio.h>

int main(void) {
    uint8_t request[24] = {8, 0, 0, 0, 0, 9, 7, 3};
    arc4random_buf(request + 8, 16);
    uint8_t reply[44] = {0x45};
    reply[9] = IPPROTO_ICMP;
    memcpy(reply + 20, request, sizeof(request));
    reply[20] = 0;
    reply[24] = 13;
    assert(matches_echo(reply, sizeof(reply), request, sizeof(request)));
    assert(matches_echo(reply + 20, 24, request, 24));
    assert(!matches_echo(reply, 19, request, 24));
    reply[43] ^= 1;
    assert(!matches_echo(reply, sizeof(reply), request, 24));
    puts("Headered and bare replies, rewritten ID, truncation and payload mismatch passed.");
    const uint32_t local = 0x7f000001;
#ifdef __APPLE__
    unsigned index = if_nametoindex("lo0");
#else
    unsigned index = if_nametoindex("lo");
#endif
    assert(index);
    LANCancelFlag *flag = lan_cancel_create();
    assert(flag);
    int listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    struct sockaddr_in addr = endpoint(local, 0);
    assert(bind(listener, (struct sockaddr *)&addr, sizeof(addr)) == 0);
    socklen_t length = sizeof(addr);
    assert(getsockname(listener, (struct sockaddr *)&addr, &length) == 0);
    assert(listen(listener, 1) == 0);
    uint16_t port = ntohs(addr.sin_port);
    LANProbeResult result = {.echo_ms = -1};
    tcp_batch(&port, 1, local, local, index, flag, &result);
    assert(result.tcp_checked && result.open_port == port && !result.tcp_refused);
    int closed_port_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    assert(closed_port_socket >= 0);
    struct sockaddr_in unused = endpoint(local, 0);
    assert(bind(closed_port_socket, (struct sockaddr *)&unused, sizeof(unused)) == 0);
    length = sizeof(unused);
    assert(getsockname(closed_port_socket, (struct sockaddr *)&unused, &length) == 0);
    uint16_t closed_port = ntohs(unused.sin_port);
    result = (LANProbeResult){.echo_ms = -1};
    tcp_batch(&closed_port, 1, local, local, index, flag, &result);
    assert(result.tcp_checked && result.tcp_refused && !result.open_port);
    result = (LANProbeResult){.echo_ms = -1};
    uint16_t candidates[] = {closed_port, closed_port, closed_port, port};
    tcp_fallback(candidates, 4, local, local, index, flag, &result);
    assert(result.tcp_checked && result.tcp_refused && result.open_port == port);
    close(listener);
    result = lan_probe(local, local, index, closed_port, flag);
    assert(result.echo_ms >= 0 || result.tcp_refused);
    printf("Loopback echo %.3f ms; TCP acceptance and refusal passed.\n", result.echo_ms);
    lan_cancel_set(flag);
    result = lan_probe(local, local, index, port, flag);
    assert(!result.echo_sent && !result.tcp_checked && !result.open_port && !result.tcp_refused);
    close(closed_port_socket);
    lan_cancel_destroy(flag);
    puts("Cancellation passed.");
}
