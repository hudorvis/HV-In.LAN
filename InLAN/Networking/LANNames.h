#ifndef INLAN_NAMES_H
#define INLAN_NAMES_H

#include "LANProbe.h"
#include <stddef.h>

// Each DNS-SD operation is scoped to one interface and has a shared, bounded deadline.
size_t lan_resolve_service(const char *name, const char *type, const char *domain, uint32_t index,
                           char *hostname, size_t capacity, uint16_t *port,
                           uint32_t *addresses, size_t limit, const LANCancelFlag *flag);
bool lan_reverse_name(uint32_t ip, uint32_t index, char *name, size_t capacity, const LANCancelFlag *flag);
#endif
