#ifndef BUS_CLOCK_H
#define BUS_CLOCK_H

/* Configure the Pico-driven serial clock as an output that idles low. */
void bus_clock_init(void);

/* Produce one complete low-to-high-to-low clock pulse for one packet byte. */
void bus_clock_pulse(void);

#endif
