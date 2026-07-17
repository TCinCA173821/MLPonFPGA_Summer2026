#ifndef HARDWARE_CONFIG_H
#define HARDWARE_CONFIG_H

/*
 * All numbers in this file are Raspberry Pi Pico GPIO (GP) numbers, not
 * physical header pin numbers. Keeping every pin and timing value here makes
 * wiring or timing changes possible without editing the protocol code.
 *
 * Data direction:
 *   BUS_D0_PIN through BUS_D7_PIN: Pico -> FPGA
 *   BUS_SCLK_PIN:                  Pico -> FPGA
 *   BUS_CS_PIN:                    Pico -> FPGA
 *   START_TO_FPGA_PIN:             Pico -> FPGA
 *   NXTPCKT_TO_PI_PIN:             FPGA -> Pico
 */
#define BUS_D0_PIN 2u
#define BUS_D1_PIN 3u
#define BUS_D2_PIN 4u
#define BUS_D3_PIN 5u
#define BUS_D4_PIN 6u
#define BUS_D5_PIN 7u
#define BUS_D6_PIN 8u
#define BUS_D7_PIN 9u

#define BUS_SCLK_PIN 10u
#define BUS_CS_PIN 11u
#define START_TO_FPGA_PIN 12u
#define NXTPCKT_TO_PI_PIN 13u

/*
 * All interface signals are active high and SCLK idles low. The FPGA samples
 * D[7:0] on each rising SCLK edge. Increase these delays if the oscilloscope or
 * logic analyzer shows setup/hold violations or if the FPGA system clock needs
 * more time to synchronize CS.
 */
#define BUS_DATA_SETUP_US 1u
#define BUS_CLOCK_HIGH_US 1u
#define BUS_DATA_HOLD_US 1u

/* Width of the active-high start pulse sent once per image inference. */
#define START_PULSE_US 10u

#endif
