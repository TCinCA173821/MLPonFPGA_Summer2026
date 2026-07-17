#include "handshake.h"

#include "hardware_config.h"

#include "pico/stdlib.h"
#include "hardware/gpio.h"

void handshake_init(void) {
    /* START is driven by the Pico and is inactive between inferences. */
    gpio_init(START_TO_FPGA_PIN);
    gpio_set_dir(START_TO_FPGA_PIN, GPIO_OUT);
    gpio_put(START_TO_FPGA_PIN, 0);

    /*
     * NXTPCKT is driven by the FPGA. The pull-down gives it a known low value
     * while the FPGA is unpowered, disconnected, or still configuring.
     */
    gpio_init(NXTPCKT_TO_PI_PIN);
    gpio_set_dir(NXTPCKT_TO_PI_PIN, GPIO_IN);
    gpio_pull_down(NXTPCKT_TO_PI_PIN);
}

void send_start(void) {
    /* The FPGA synchronizes this active-high pulse into its own clock domain. */
    gpio_put(START_TO_FPGA_PIN, 1);
    busy_wait_us_32(START_PULSE_US);
    gpio_put(START_TO_FPGA_PIN, 0);
}

void wait_for_next_packet(void) {
    /* Busy-waiting is intentional: no other Pico task runs during inference. */
    while (!gpio_get(NXTPCKT_TO_PI_PIN)) {
        tight_loop_contents();
    }
}

void wait_for_next_packet_end(void) {
    /* Require a complete high-to-low handshake before accepting a new request. */
    while (gpio_get(NXTPCKT_TO_PI_PIN)) {
        tight_loop_contents();
    }
}
