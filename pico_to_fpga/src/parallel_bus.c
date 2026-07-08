#include "parallel_bus.h"
#include "parallel_bus_config.h"

#include "pico/stdlib.h"
#include "hardware/gpio.h"

#include <stdbool.h>

static const uint DATA_PINS[8] = {
    BUS_D0_PIN,
    BUS_D1_PIN,
    BUS_D2_PIN,
    BUS_D3_PIN,
    BUS_D4_PIN,
    BUS_D5_PIN,
    BUS_D6_PIN,
    BUS_D7_PIN
};

static inline void bus_delay(void) {
    busy_wait_us_32(BUS_DELAY_US);
}

static inline void bus_set_cs(bool active) {
#if BUS_CS_ACTIVE_HIGH
    gpio_put(BUS_CS_PIN, active ? 1 : 0);
#else
    gpio_put(BUS_CS_PIN, active ? 0 : 1);
#endif
}

static inline void bus_set_data(uint8_t value) {
    for (int bit = 0; bit < 8; bit++) {
        gpio_put(DATA_PINS[bit], (value >> bit) & 1u);
    }
}

static inline void bus_pulse_clock(void) {
    bus_delay();

    gpio_put(BUS_SCLK_PIN, 1);
    bus_delay();

    gpio_put(BUS_SCLK_PIN, 0);
    bus_delay();
}

static inline void bus_send_byte_raw(uint8_t value) {
    bus_set_data(value);
    bus_pulse_clock();
}

void parallel_bus_init(void) {
    for (int bit = 0; bit < 8; bit++) {
        gpio_init(DATA_PINS[bit]);
        gpio_set_dir(DATA_PINS[bit], GPIO_OUT);
        gpio_put(DATA_PINS[bit], 0);
    }

    gpio_init(BUS_SCLK_PIN);
    gpio_set_dir(BUS_SCLK_PIN, GPIO_OUT);
    gpio_put(BUS_SCLK_PIN, 0);

    gpio_init(BUS_CS_PIN);
    gpio_set_dir(BUS_CS_PIN, GPIO_OUT);
    bus_set_cs(false);
}

void parallel_bus_send_bytes(const uint8_t *bytes, size_t length) {
    if (bytes == NULL || length == 0) {
        return;
    }

    bus_set_cs(true);
    bus_delay();

    for (size_t i = 0; i < length; i++) {
        bus_send_byte_raw(bytes[i]);
    }

    bus_set_cs(false);
    bus_delay();
}

void parallel_bus_send_u16(uint16_t word) {
    uint8_t bytes[2] = {
        (uint8_t)((word >> 8) & 0xFF),
        (uint8_t)(word & 0xFF)
    };

    parallel_bus_send_bytes(bytes, 2);
}

void parallel_bus_send_u32(uint32_t word) {
    uint8_t bytes[4] = {
        (uint8_t)((word >> 24) & 0xFF),
        (uint8_t)((word >> 16) & 0xFF),
        (uint8_t)((word >> 8)  & 0xFF),
        (uint8_t)(word & 0xFF)
    };

    parallel_bus_send_bytes(bytes, 4);
}