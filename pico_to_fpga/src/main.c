#include <stdint.h>
#include <stdio.h>

#include "pico/stdlib.h"

#include "parallel_bus.h"

int main(void) {
    stdio_init_all();
    sleep_ms(2000);

    parallel_bus_init();

    const uint16_t test_word = 0xABCDu;

    while (1) {
        printf("Sending 0x%04X\n", test_word);
        parallel_bus_send_u16(test_word);
        sleep_ms(1000);
    }
}
