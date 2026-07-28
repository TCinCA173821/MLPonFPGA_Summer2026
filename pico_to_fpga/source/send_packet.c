#include "send_packet.h"

#include "bus_clock.h"
#include "form_packet.h"
#include "hardware_config.h"

#include "pico/stdlib.h"
#include "hardware/gpio.h"

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
    for (int bit = 0; bit < 8; ++bit) {
        gpio_put(data_pins[bit], (value >> bit) & 1u);
    }
}

void send_packet_init(void) {
    for (int bit = 0; bit < 8; ++bit) {
        gpio_init(data_pins[bit]);
        gpio_set_dir(data_pins[bit], GPIO_OUT);
        gpio_put(data_pins[bit], 0);
    }

    gpio_init(BUS_CS_PIN);
    gpio_set_dir(BUS_CS_PIN, GPIO_OUT);
    gpio_put(BUS_CS_PIN, 0);

    bus_clock_init();
}

void send_packet(void) {
    gpio_put(BUS_CS_PIN, 1);

    for (uint16_t i = 0; i < PACKET_BYTE_COUNT; ++i) {
        set_data_pins(pkt[i]);
        bus_clock_pulse();
    }

    /* Keep CS high until main.c observes the FPGA acknowledgement. */
}

void send_packet_end(void) {
    gpio_put(BUS_CS_PIN, 0);
}
