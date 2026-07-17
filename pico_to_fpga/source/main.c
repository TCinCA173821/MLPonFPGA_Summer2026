#include <stdint.h>
#include <stdio.h>

#include "pico/stdlib.h"

#include "form_packet.h"
#include "handshake.h"
#include "send_packet.h"
#include "usb_image.h"

/*
 * Four physical MAC lanes process the 16 hidden nodes in four groups. Every
 * hidden group needs one bias packet followed by one packet per image pixel.
 */
#define HIDDEN_GROUP_COUNT 4u
#define HIDDEN_PACKETS_PER_GROUP IMAGE_PIXEL_COUNT

/*
 * Ten output nodes require three hardware groups: nodes 0-3, 4-7, and 8-9.
 * Every group consumes all 16 hidden activations, so it needs 16 packets.
 */
#define OUTPUT_GROUP_COUNT 3u
#define OUTPUT_PACKETS_PER_GROUP HIDDEN_NODE_COUNT

/*
 * Shared global state requested by the bridge design. Each image element uses
 * only its low nibble, while each pkt element is a complete bus byte.
 */
uint8_t image[IMAGE_PIXEL_COUNT] = {0};
uint8_t pkt[PACKET_BYTE_COUNT] = {0};

/* These count packets already formed for each of the three packet types. */
uint16_t bias_counter = 0u;
uint16_t hidden_counter = 0u;
uint16_t output_counter = 0u;

static void transfer_packet(packet_type_t type, uint16_t cnt) {
    /* The Pico never sends unsolicited data; it first waits for the FPGA. */
    wait_for_next_packet();

    /* Build pkt[] from model/image data, then clock its four bytes to the FPGA. */
    form_packet(type, cnt);
    send_packet();

    /* Consume the current request fully before looking for the next one. */
    wait_for_next_packet_end();
}

static void stream_inference_data(void) {
    uint16_t group;
    uint16_t packet;

    /* Reuse the same firmware for repeated images by restarting all counters. */
    reset_packet_counters();

    /* Tell the FPGA that the image buffer and model data are ready. */
    send_start();

    /*
     * Hidden-layer order for each group:
     *   1 bias packet
     *   196 weight/pixel packets
     */
    for (group = 0; group < HIDDEN_GROUP_COUNT; group++) {
        transfer_packet(BIAS, bias_counter);

        for (packet = 0; packet < HIDDEN_PACKETS_PER_GROUP; packet++) {
            transfer_packet(HIDDEN, hidden_counter);
        }
    }

    /*
     * Output-layer order for each group:
     *   1 bias packet
     *   16 weight packets, one for each hidden activation
     */
    for (group = 0; group < OUTPUT_GROUP_COUNT; group++) {
        transfer_packet(BIAS, bias_counter);

        for (packet = 0; packet < OUTPUT_PACKETS_PER_GROUP; packet++) {
            transfer_packet(OUTPUT, output_counter);
        }
    }
}

int main(void) {
    /* Enable Pico SDK standard I/O; CMake routes it through USB CDC. */
    stdio_init_all();

    /* Put every bus and handshake pin into a safe, known idle state. */
    send_packet_init();
    handshake_init();

    while (1) {
        /* One loop iteration receives and streams exactly one image inference. */
        usb_receive_image(image);
        stream_inference_data();
        printf("TRANSFER_OK\n");
    }
}
