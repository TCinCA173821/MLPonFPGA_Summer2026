#ifndef DMA_PACKET_STREAM_H
#define DMA_PACKET_STREAM_H

#include <stddef.h>
#include <stdint.h>

/* Configure PIO0, its completion interrupt, and one DMA channel. */
void dma_packet_stream_init(void);

/* Arm DMA and prefill the PIO TX FIFO before START is asserted. */
void dma_packet_stream_start(const uint32_t *packet_words,
                             size_t packet_count);

/* Block until PIO reports that the FPGA acknowledged every armed packet. */
void dma_packet_stream_wait(size_t packet_count);

#endif
