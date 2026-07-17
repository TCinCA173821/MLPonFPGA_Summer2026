#include "send_packet.h"

#include "bus_clock.h"
#include "form_packet.h"
#include "hardware_config.h"

#include "pico/stdlib.h"
#include "hardware/gpio.h"

/*
 * Map bit position 0-7 to the matching physical Pico GPIO. Keeping this table
 * makes the bit loop easy to read and allows noncontiguous mappings later.
 */
static const uint data_pins[8] = {
    BUS_D0_PIN,
    BUS_D1_PIN,
    BUS_D2_PIN,
    BUS_D3_PIN,
    BUS_D4_PIN,
    BUS_D5_PIN,
    BUS_D6_PIN,
    BUS_D7_PIN
};

static void set_data_pins(uint8_t value) {
    int bit;

    for (bit = 0; bit < 8; bit++) {
        /* Extract one bit and place it on the corresponding D pin. */
        gpio_put(data_pins[bit], (value >> bit) & 1u);
    }
}

void send_packet_init(void) {
    int bit;

    /* All eight data pins are Pico outputs and begin at logic zero. */
    for (bit = 0; bit < 8; bit++) {
        gpio_init(data_pins[bit]);
        gpio_set_dir(data_pins[bit], GPIO_OUT);
        gpio_put(data_pins[bit], 0);
    }

    /* Chip select is active high and remains low between packets. */
    gpio_init(BUS_CS_PIN);
    gpio_set_dir(BUS_CS_PIN, GPIO_OUT);
    gpio_put(BUS_CS_PIN, 0);

    /* SCLK initialization lives in bus_clock.c so all timing is centralized. */
    bus_clock_init();
}

void send_packet(void) {
    uint16_t i;

    /* CS encloses one complete 32-bit transaction made from four bytes. */
    gpio_put(BUS_CS_PIN, 1);

    for (i = 0; i < PACKET_BYTE_COUNT; i++) {
        /*
         * Set the byte while SCLK is low. bus_clock_pulse() waits for setup,
         * raises SCLK so the FPGA captures the byte, and lowers SCLK again.
         * Bytes are intentionally sent in pkt[0], pkt[1], pkt[2], pkt[3] order.
         */
        set_data_pins(pkt[i]);
        bus_clock_pulse();
    }

    /* The FPGA uses falling CS to recognize the end of the four-byte packet. */
    gpio_put(BUS_CS_PIN, 0);
}
