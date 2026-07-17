#include "bus_clock.h"

#include "hardware_config.h"

#include "pico/stdlib.h"
#include "hardware/gpio.h"

void bus_clock_init(void) {
    /* The FPGA captures D[7:0] on rising edges, so the idle state is low. */
    gpio_init(BUS_SCLK_PIN);
    gpio_set_dir(BUS_SCLK_PIN, GPIO_OUT);
    gpio_put(BUS_SCLK_PIN, 0);
}

void bus_clock_pulse(void) {
    /* Allow D[7:0] to settle before creating the sampling edge. */
    busy_wait_us_32(BUS_DATA_SETUP_US);

    /* This rising edge causes the FPGA input shift register to capture a byte. */
    gpio_put(BUS_SCLK_PIN, 1);
    busy_wait_us_32(BUS_CLOCK_HIGH_US);

    /* Return to the idle level and preserve data for the required hold time. */
    gpio_put(BUS_SCLK_PIN, 0);
    busy_wait_us_32(BUS_DATA_HOLD_US);
}
