#ifndef USB_IMAGE_H
#define USB_IMAGE_H

#include <stdint.h>

#include "weights.h"

/*
 * Wait for one framed image over USB CDC and write its 196 low-nibble pixels
 * into destination. The function blocks until a complete image is available.
 */
void usb_receive_image(uint8_t destination[IMAGE_PIXEL_COUNT]);

#endif
