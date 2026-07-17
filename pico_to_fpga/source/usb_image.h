#ifndef USB_IMAGE_H
#define USB_IMAGE_H

#include <stdint.h>

#include "weights.h"

void usb_receive_image(uint8_t destination[IMAGE_PIXEL_COUNT]);

#endif
