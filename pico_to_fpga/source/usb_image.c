#include "usb_image.h"

#include <stdio.h>

#include "pico/stdlib.h"
#include "pico/stdio_usb.h"

static const uint8_t image_header[4] = {'I', 'M', 'G', '1'};

static uint8_t read_usb_byte(void) {
    return (uint8_t)getchar();
}

static void wait_for_image_header(void) {
    uint16_t matched = 0u;

    while (matched < sizeof(image_header)) {
        uint8_t value = read_usb_byte();

        if (value == image_header[matched]) {
            matched++;
        } else if (value == image_header[0]) {
            matched = 1u;
        } else {
            matched = 0u;
        }
    }
}

void usb_receive_image(uint8_t destination[IMAGE_PIXEL_COUNT]) {
    uint16_t i;

    while (!stdio_usb_connected()) {
        sleep_ms(10);
    }

    printf("READY\n");
    wait_for_image_header();

    for (i = 0; i < IMAGE_PIXEL_COUNT; i++) {
        // The laptop sends one byte per pixel with the pixel in the low nibble.
        destination[i] = (uint8_t)(read_usb_byte() & 0x0Fu);
    }

    printf("IMAGE_OK\n");
}
