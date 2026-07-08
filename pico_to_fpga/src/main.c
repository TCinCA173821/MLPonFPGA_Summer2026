#include <stdint.h>

#include "pico/stdlib.h"

#include "parallel_bus.h"

int main(void) {
    stdio_init_all();

    parallel_bus_init();

    const uint16_t test_word = 0xABCDu;

    while (1) {
        parallel_bus_send_u16(test_word);
        sleep_ms(1000);
    }
}
