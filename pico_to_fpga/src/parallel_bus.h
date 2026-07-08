#ifndef PARALLEL_BUS_H
#define PARALLEL_BUS_H

#include <stdint.h>
#include <stddef.h>

void parallel_bus_init(void);

void parallel_bus_send_bytes(const uint8_t *bytes, size_t length);
void parallel_bus_send_u16(uint16_t word);

#endif
