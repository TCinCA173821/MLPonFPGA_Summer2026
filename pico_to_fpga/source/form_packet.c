#include "form_packet.h"

#include <stddef.h>

/* One hidden packet is required for each input pixel in a four-neuron group. */
#define HIDDEN_PACKETS_PER_GROUP IMAGE_PIXEL_COUNT

/* One output packet is required for each of the 16 hidden-layer results. */
#define OUTPUT_PACKETS_PER_GROUP HIDDEN_NODE_COUNT

/* Four output nodes, each with 16 incoming weights, use 64 real weights. */
#define FULL_OUTPUT_GROUP_WEIGHT_COUNT (PACKET_BYTE_COUNT * HIDDEN_NODE_COUNT)

/*
 * Convert a signed INT4 weight (-8 through 7) into the upper nibble of a byte.
 *
 * The mask keeps the low four-bit two's-complement representation. For example,
 * -1 is 0xFF as an int8_t, becomes 0x0F after masking, and becomes 0xF0 after
 * the left shift. The lower nibble remains zero for later OR operations.
 */
static uint8_t weight_in_upper_nibble(int8_t weight) {
    return (uint8_t)(((uint8_t)weight & 0x0Fu) << 4);
}

void form_packet(packet_type_t type, uint16_t cnt) {
    uint16_t i;

    if (type == BIAS) {
        /* Each bias packet carries four consecutive signed 8-bit biases. */
        uint16_t first_bias = (uint16_t)(cnt * PACKET_BYTE_COUNT);

        for (i = 0; i < PACKET_BYTE_COUNT; i++) {
            uint16_t bias_index = (uint16_t)(first_bias + i);

            /*
             * There are 26 biases, so the seventh and final bias packet has
             * only two real values. Its remaining two bytes are safely zero.
             */
            pkt[i] = bias_index < BIAS_COUNT ? (uint8_t)biases[bias_index] : 0u;
        }

        /* cnt identifies the packet just formed; cnt + 1 is the next request. */
        bias_counter = (uint16_t)(cnt + 1u);
    }

    if (type == HIDDEN) {
        /* Four adjacent weights belong to four nodes processing one pixel. */
        uint16_t first_weight = (uint16_t)(cnt * PACKET_BYTE_COUNT);

        /*
         * The modulo restarts the pixel index after 196 packets, when the next
         * four-hidden-node group begins. Every byte in this packet uses exactly
         * the same pixel.
         */
        uint16_t pixel_index = (uint16_t)(cnt % HIDDEN_PACKETS_PER_GROUP);
        uint8_t pixel = (uint8_t)(image[pixel_index] & 0x0Fu);

        for (i = 0; i < PACKET_BYTE_COUNT; i++) {
            uint16_t weight_index = (uint16_t)(first_weight + i);

            if (weight_index < LAYER_ONE_WEIGHT_COUNT) {
                /* Final byte layout: WWWWPPPP (signed weight, unsigned pixel). */
                pkt[i] = (uint8_t)(weight_in_upper_nibble(layer_one[weight_index]) | pixel);
            } else {
                pkt[i] = 0u;
            }
        }

        hidden_counter = (uint16_t)(cnt + 1u);
    }

    if (type == OUTPUT) {
        /*
         * The output layer is processed as three groups of four MAC lanes:
         * nodes 0-3, nodes 4-7, and nodes 8-9 plus two unused lanes.
         */
        uint16_t output_group = (uint16_t)(cnt / OUTPUT_PACKETS_PER_GROUP);
        uint16_t hidden_index = (uint16_t)(cnt % OUTPUT_PACKETS_PER_GROUP);
        uint16_t weights_before_group;
        uint16_t nodes_in_group;

        if (output_group < 2u) {
            /* The first two groups each contain four nodes and 64 weights. */
            weights_before_group = (uint16_t)(output_group * FULL_OUTPUT_GROUP_WEIGHT_COUNT);
            nodes_in_group = PACKET_BYTE_COUNT;
        } else {
            /* The last group begins after 128 weights and contains two nodes. */
            weights_before_group = (uint16_t)(2u * FULL_OUTPUT_GROUP_WEIGHT_COUNT);
            nodes_in_group = 2u;
        }

        for (i = 0; i < PACKET_BYTE_COUNT; i++) {
            if (i < nodes_in_group) {
                uint16_t weight_index = (uint16_t)(
                    weights_before_group + hidden_index * nodes_in_group + i
                );

                /* Output weights occupy WWWW0000; the FPGA supplies activation. */
                pkt[i] = weight_index < LAYER_TWO_WEIGHT_COUNT
                    ? weight_in_upper_nibble(layer_two[weight_index])
                    : 0u;
            } else {
                /* No trained output node exists for these two hardware lanes. */
                pkt[i] = 0u;
            }
        }

        output_counter = (uint16_t)(cnt + 1u);
    }
}

void reset_packet_counters(void) {
    /* A new image inference always begins with the first packet of each type. */
    bias_counter = 0u;
    hidden_counter = 0u;
    output_counter = 0u;
}
