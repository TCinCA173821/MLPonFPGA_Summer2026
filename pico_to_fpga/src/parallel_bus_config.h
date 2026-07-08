#ifndef PARALLEL_BUS_CONFIG_H
#define PARALLEL_BUS_CONFIG_H

// active-high chip select
#define PARALLEL_BUS_CS_ACTIVE_HIGH 1


#define PARALLEL_BUS_DATA_PINS { \
    2u, \
    3u, \
    4u, \
    5u, \
    6u, \
    7u, \
    8u, \
    9u  \
}

#define PARALLEL_BUS_SCLK_PIN 10u
#define PARALLEL_BUS_CS_PIN   11u


#define PARALLEL_BUS_DELAY_US 1u

#endif