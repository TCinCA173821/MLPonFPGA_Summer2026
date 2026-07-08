#include "parallel_bus.h"
#include "parallel_bus_config.h"

#include <stdbool.h>

#include "hardware/gpio.h"
#include "pico/time.h"

static const uint DATA_PINS[8] = PARALLEL_BUS_DATA_PINS;

static inline void bus_delay(void) {
    busy_wait_us_32(PARALLEL_BUS_DELAY_US);
}

static inline void bus_set_cs(bool active) {
    const bool level = PARALLEL_BUS_CS_ACTIVE_HIGH ? active : !active;
    gpio_put(PARALLEL_BUS_CS_PIN, level);
}

static inline void bus_set_data(uint8_t value) {
    for (size_t bit = 0; bit < 8; bit++) {
        gpio_put(DATA_PINS[bit], ((value >> bit) & 1u) != 0u);
    }
}

static inline void bus_pulse_clock(void) {
    bus_delay();

    gpio_put(PARALLEL_BUS_SCLK_PIN, 1);
    bus_delay();

    gpio_put(PARALLEL_BUS_SCLK_PIN, 0);
    bus_delay();
}

static inline void bus_send_byte_raw(uint8_t value) {
    bus_set_data(value);
    bus_pulse_clock();
}

void parallel_bus_init(void) {
    for (size_t bit = 0; bit < 8; bit++) {
        gpio_init(DATA_PINS[bit]);
        gpio_put(DATA_PINS[bit], 0);
        gpio_set_dir(DATA_PINS[bit], GPIO_OUT);
    }

    gpio_init(PARALLEL_BUS_SCLK_PIN);
    gpio_put(PARALLEL_BUS_SCLK_PIN, 0);
    gpio_set_dir(PARALLEL_BUS_SCLK_PIN, GPIO_OUT);

    gpio_init(PARALLEL_BUS_CS_PIN);
    bus_set_cs(false);
    gpio_set_dir(PARALLEL_BUS_CS_PIN, GPIO_OUT);
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
        (uint8_t)(word >> 8),
        (uint8_t)word
    };

    parallel_bus_send_bytes(bytes, 2);
}
