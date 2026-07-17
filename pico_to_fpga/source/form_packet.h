#ifndef FORM_PACKET_H
#define FORM_PACKET_H

#include <stdint.h>

#include "weights.h"

/* The packet requested by the FPGA always belongs to one of these types. */
typedef enum {
    BIAS,
    HIDDEN,
    OUTPUT
} packet_type_t;

/*
 * Shared transfer state
 * ---------------------
 * main.c owns these global arrays and counters. They are declared with extern
 * here so form_packet.c and send_packet.c refer to the same memory rather than
 * creating separate copies.
 *
 * image[] stores one 4-bit pixel in the low nibble of each byte: 0000PPPP.
 * pkt[] is the mutable four-byte packet most recently prepared for the FPGA.
 * Each counter is a packet counter, not a raw byte or weight counter.
 */
extern uint8_t image[IMAGE_PIXEL_COUNT];
extern uint8_t pkt[PACKET_BYTE_COUNT];
extern uint16_t bias_counter;
extern uint16_t hidden_counter;
extern uint16_t output_counter;

/* Fill global pkt[] for request number cnt and advance the matching counter. */
void form_packet(packet_type_t type, uint16_t cnt);

/* Start a new inference with all three packet counters set back to zero. */
void reset_packet_counters(void);

#endif
