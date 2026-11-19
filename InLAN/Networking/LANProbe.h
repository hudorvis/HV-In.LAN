#ifndef INLAN_PROBE_H
#define INLAN_PROBE_H

#include <stdbool.h>
#include <stdint.h>

typedef struct LANCancelFlag LANCancelFlag;
LANCancelFlag *lan_cancel_create(void);
void lan_cancel_set(LANCancelFlag *flag);
bool lan_cancelled(const LANCancelFlag *flag);
void lan_cancel_destroy(LANCancelFlag *flag);

typedef struct {
    double echo_ms;       // Negative when there is no matching echo reply.
    uint16_t open_port;   // Only a completed TCP handshake sets this.
    bool echo_sent;
    bool tcp_checked;     // At least one TCP attempt was issued on the selected LAN.
    bool tcp_refused;     // A refusal is reachability evidence, not an open service.
    bool access_denied;
    bool local_error;
} LANProbeResult;

// IPv4 arguments are in host byte order. Both sockets use the selected LAN interface.
LANProbeResult lan_probe(uint32_t address, uint32_t local_address, uint32_t interface_index,
                         uint16_t preferred_port, const LANCancelFlag *flag);
#endif
