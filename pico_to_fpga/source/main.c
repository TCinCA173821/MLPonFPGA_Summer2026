#include <stdint.h>
#include <stdio.h>

#include "pico/stdlib.h"

#include "dma_packet_stream.h"
#include "form_packet.h"
#include "handshake.h"
#include "usb_image.h"

#define HIDDEN_GROUP_COUNT 4u
#define HIDDEN_PACKETS_PER_GROUP IMAGE_PIXEL_COUNT
#define OUTPUT_GROUP_COUNT 3u
#define OUTPUT_PACKETS_PER_GROUP HIDDEN_NODE_COUNT

#define HIDDEN_STREAM_PACKET_COUNT \
    (HIDDEN_GROUP_COUNT * (1u + HIDDEN_PACKETS_PER_GROUP))
#define OUTPUT_STREAM_PACKET_COUNT \
    (OUTPUT_GROUP_COUNT * (1u + OUTPUT_PACKETS_PER_GROUP))
#define TOTAL_PACKET_COUNT \
    (HIDDEN_STREAM_PACKET_COUNT + OUTPUT_STREAM_PACKET_COUNT)

uint8_t image[IMAGE_PIXEL_COUNT] = {0};
uint8_t pkt[PACKET_BYTE_COUNT] = {0};

uint16_t bias_counter = 0u;
uint16_t hidden_counter = 0u;
uint16_t output_counter = 0u;

/* Complete DMA source array: 839 packets x 4 bytes = 3,356 bytes. */
static uint32_t packet_words[TOTAL_PACKET_COUNT];

static uint32_t pack_current_packet(void) {
    return ((uint32_t)pkt[0] << 24) |
           ((uint32_t)pkt[1] << 16) |
           ((uint32_t)pkt[2] << 8) |
           (uint32_t)pkt[3];
}

static void append_packet(size_t *index, packet_type_t type, uint16_t count) {
    form_packet(type, count);
    packet_words[*index] = pack_current_packet();
    (*index)++;
}

static void build_packet_array(void) {
    size_t index = 0u;

    reset_packet_counters();

    for (uint16_t group = 0; group < HIDDEN_GROUP_COUNT; ++group) {
        append_packet(&index, BIAS, bias_counter);
        for (uint16_t packet = 0;
             packet < HIDDEN_PACKETS_PER_GROUP;
             ++packet) {
            append_packet(&index, HIDDEN, hidden_counter);
        }
    }

    for (uint16_t group = 0; group < OUTPUT_GROUP_COUNT; ++group) {
        append_packet(&index, BIAS, bias_counter);
        for (uint16_t packet = 0;
             packet < OUTPUT_PACKETS_PER_GROUP;
             ++packet) {
            append_packet(&index, OUTPUT, output_counter);
        }
    }

    printf("PACKET_ARRAY_OK count=%u bytes=%u\n",
           (unsigned)index,
           (unsigned)(index * sizeof(packet_words[0])));
}

static void stream_packet_array(void) {
    /*
     * Arm DMA before START. PIO waits at NXTPCKT with packet 1 already
     * available in its FIFO, eliminating the first-request startup race.
     */
    dma_packet_stream_start(packet_words, TOTAL_PACKET_COUNT);
    send_start();

    /* Lower START once the FPGA acknowledges the inference request. */
    wait_for_next_packet();
    send_start_end();
    printf("FIRST_REQUEST_OK\n");

    dma_packet_stream_wait(TOTAL_PACKET_COUNT);
}

int main(void) {
    stdio_init_all();

    handshake_init();
    dma_packet_stream_init();

    while (true) {
        usb_receive_image(image);
        build_packet_array();
        stream_packet_array();
        printf("TRANSFER_OK\n");
    }
}
