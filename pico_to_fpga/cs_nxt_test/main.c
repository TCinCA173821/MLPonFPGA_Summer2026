#include <stdio.h>

#include "pico/stdlib.h"
#include "pico/stdio_usb.h"

enum {
    DATA_BASE_PIN = 2,
    DATA_PIN_COUNT = 8,
    SCLK_PIN = 10,
    CS_PIN = 11,
    START_PIN = 12,
    NXTPCKT_PIN = 13
};

static bool wait_for_level(bool level, uint32_t timeout_ms) {
    absolute_time_t deadline = make_timeout_time_ms(timeout_ms);

    while (gpio_get(NXTPCKT_PIN) != level) {
        if (absolute_time_diff_us(get_absolute_time(), deadline) <= 0) {
            return false;
        }
        tight_loop_contents();
    }
    return true;
}

static void send_zero_packet(void) {
    gpio_put(CS_PIN, 1);
    printf("CS=1 NXT=%d\n", gpio_get(NXTPCKT_PIN));

    for (uint pulse = 0; pulse < 4; ++pulse) {
        sleep_ms(10);
        gpio_put(SCLK_PIN, 1);
        printf("SCLK pulse %u high NXT=%d\n",
               pulse + 1, gpio_get(NXTPCKT_PIN));
        sleep_ms(10);
        gpio_put(SCLK_PIN, 0);
    }

    sleep_ms(10);
    gpio_put(CS_PIN, 0);
    printf("CS=0 NXT=%d\n", gpio_get(NXTPCKT_PIN));
}

int main(void) {
    stdio_init_all();
    while (!stdio_usb_connected()) {
        sleep_ms(10);
    }
    sleep_ms(500);

    for (uint pin = DATA_BASE_PIN;
         pin < DATA_BASE_PIN + DATA_PIN_COUNT;
         ++pin) {
        gpio_init(pin);
        gpio_set_dir(pin, GPIO_OUT);
        gpio_put(pin, 0);
    }

    gpio_init(SCLK_PIN);
    gpio_set_dir(SCLK_PIN, GPIO_OUT);
    gpio_put(SCLK_PIN, 0);

    gpio_init(CS_PIN);
    gpio_set_dir(CS_PIN, GPIO_OUT);
    gpio_put(CS_PIN, 0);

    gpio_init(START_PIN);
    gpio_set_dir(START_PIN, GPIO_OUT);
    gpio_put(START_PIN, 0);

    gpio_init(NXTPCKT_PIN);
    gpio_set_dir(NXTPCKT_PIN, GPIO_IN);
    gpio_pull_down(NXTPCKT_PIN);

    printf("CS/NXTPCKT TEST READY\n");
    printf("Initial: CS=0 NXT=%d\n", gpio_get(NXTPCKT_PIN));

    gpio_put(START_PIN, 1);
    printf("START=1; waiting up to 5 seconds for first NXT=1\n");

    if (!wait_for_level(true, 5000)) {
        printf("FAIL: first NXTPCKT never asserted\n");
        while (true) {
            sleep_ms(1000);
        }
    }

    printf("PASS: first NXT=1\n");
    gpio_put(START_PIN, 0);
    printf("START=0\n");

    send_zero_packet();

    if (!wait_for_level(false, 1000)) {
        printf("FAIL: NXTPCKT did not return low\n");
    } else {
        printf("PASS: packet acknowledged with NXT=0\n");
    }

    printf("Waiting up to 5 seconds for second NXT=1\n");
    if (wait_for_level(true, 5000)) {
        printf("PASS: SECOND NXTPCKT ASSERTED\n");
    } else {
        printf("FAIL: SECOND NXTPCKT NEVER ASSERTED\n");
    }

    while (true) {
        printf("IDLE: CS=%d NXT=%d\n",
               gpio_get(CS_PIN), gpio_get(NXTPCKT_PIN));
        sleep_ms(1000);
    }
}
