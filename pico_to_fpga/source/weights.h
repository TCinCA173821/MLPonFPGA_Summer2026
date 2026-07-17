#ifndef WEIGHTS_H
#define WEIGHTS_H

#include <stdint.h>

/* Fixed neural-network dimensions. */
#define IMAGE_PIXEL_COUNT 196u
#define HIDDEN_NODE_COUNT 16u
#define OUTPUT_NODE_COUNT 10u
#define PACKET_BYTE_COUNT 4u

/* Number of trained values expected from the model export process. */
#define LAYER_ONE_WEIGHT_COUNT (IMAGE_PIXEL_COUNT * HIDDEN_NODE_COUNT)
#define LAYER_TWO_WEIGHT_COUNT (HIDDEN_NODE_COUNT * OUTPUT_NODE_COUNT)
#define BIAS_COUNT (HIDDEN_NODE_COUNT + OUTPUT_NODE_COUNT)

/*
 * Production firmware stores model data in flash as const arrays. The testbench
 * defines PICO_TO_FPGA_TEST so it can fill the same arrays with new randomized
 * values before each test pass.
 */
#ifdef PICO_TO_FPGA_TEST
#define MODEL_DATA_CONST
#else
#define MODEL_DATA_CONST const
#endif

/*
 * layer_one is stored in the exact order in which hidden packets are sent:
 *
 *   group 0, pixel 0: weights for hidden nodes 0, 1, 2, 3
 *   group 0, pixel 1: weights for hidden nodes 0, 1, 2, 3
 *   ...
 *   group 1, pixel 0: weights for hidden nodes 4, 5, 6, 7
 *
 * This gives 4 groups * 196 pixels * 4 weights = 3136 weights. Exporting the
 * array in packet order lets form_packet() read four adjacent values at a time.
 */
extern MODEL_DATA_CONST int8_t layer_one[LAYER_ONE_WEIGHT_COUNT];

/*
 * layer_two is also stored in packet order:
 *
 *   values   0-63: output nodes 0-3, grouped by hidden input
 *   values  64-127: output nodes 4-7, grouped by hidden input
 *   values 128-159: output nodes 8-9, grouped by hidden input
 *
 * The last output group contains only two nodes, so form_packet() inserts two
 * zero bytes into each packet instead of storing fake weights in this array.
 */
extern MODEL_DATA_CONST int8_t layer_two[LAYER_TWO_WEIGHT_COUNT];

/* Bias indices 0-15 are hidden biases; indices 16-25 are output biases. */
extern MODEL_DATA_CONST int8_t biases[BIAS_COUNT];

#undef MODEL_DATA_CONST

#endif
