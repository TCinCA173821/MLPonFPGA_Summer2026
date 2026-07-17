#include "usb_image.h"

#include <stdio.h>

#include "pico/stdlib.h"
#include "pico/stdio_usb.h"

/*
 * Laptop-to-Pico frame format:
 *
 *   byte 0-3: ASCII "IMG1"
 *   byte 4-199: 196 pixels, one pixel per byte in the low nibble
 *
 * A fixed header lets the Pico recover alignment if the laptop reconnects or
 * an incomplete transfer is abandoned. Image length is fixed by the model.
 */
static const uint8_t image_header[4] = {'I', 'M', 'G', '1'};

static uint8_t read_usb_byte(void) {
    /* getchar() reads one raw byte from the USB CDC standard-input stream. */
    return (uint8_t)getchar();
}

static void wait_for_image_header(void) {
    uint16_t matched = 0u;

    /* Scan the incoming stream until all four header bytes match in order. */
    while (matched < sizeof(image_header)) {
        uint8_t value = read_usb_byte();

        if (value == image_header[matched]) {
            matched++;
        } else if (value == image_header[0]) {
            /* This byte could already be the beginning of a new "IMG1". */
            matched = 1u;
        } else {
            matched = 0u;
        }
    }
}

void usb_receive_image(uint8_t destination[IMAGE_PIXEL_COUNT]) {
    uint16_t i;

    /* Do not print READY until a laptop has actually opened the USB COM port. */
    while (!stdio_usb_connected()) {
        sleep_ms(10);
    }

    printf("READY\n");
    wait_for_image_header();

    for (i = 0; i < IMAGE_PIXEL_COUNT; i++) {
        /*
         * The mask guarantees 0000PPPP even if a sender accidentally leaves
         * nonzero bits in the unused upper nibble.
         */
        destination[i] = (uint8_t)(read_usb_byte() & 0x0Fu);
    }

    printf("IMAGE_OK\n");
}
