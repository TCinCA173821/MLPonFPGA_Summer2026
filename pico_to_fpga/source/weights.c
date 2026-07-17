#include "weights.h"

/*
 * Model-data placeholder
 * ----------------------
 * Replace these zero-filled initializers with the values exported by the
 * trained and quantized model. Keep the array names and lengths unchanged.
 *
 * layer_one and layer_two contain signed INT4 weights represented in int8_t
 * elements. Every value must therefore be between -8 and 7. form_packet()
 * later extracts the low four-bit two's-complement representation.
 *
 * Biases use full signed bytes because a bias packet sends all eight bits.
 * The exact ordering required for each array is documented in weights.h.
 */
const int8_t layer_one[LAYER_ONE_WEIGHT_COUNT] = {0};
const int8_t layer_two[LAYER_TWO_WEIGHT_COUNT] = {0};
const int8_t biases[BIAS_COUNT] = {0};
