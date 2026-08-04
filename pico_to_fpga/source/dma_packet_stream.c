#include "dma_packet_stream.h"

#include <stdio.h>

#include "hardware_config.h"
#include "sendpckt.pio.h"

#include "hardware/dma.h"
#include "hardware/gpio.h"
#include "hardware/irq.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"

static PIO packet_pio = pio0;
static uint packet_sm;
static uint packet_program_offset;
static int packet_dma_channel;
static volatile uint32_t completed_packets;

static void packet_complete_irq(void) {
    if (pio_interrupt_get(packet_pio, 0)) {
        pio_interrupt_clear(packet_pio, 0);
        completed_packets++;
    }
}

void dma_packet_stream_init(void) {
    uint offset = pio_add_program(packet_pio, &sendpckt_program);
    packet_program_offset = offset;
    packet_sm = pio_claim_unused_sm(packet_pio, true);

    /* 125 MHz / 1.0416667 / 12 PIO cycles = nominal 10 MHz SCLK. */
    sendpckt_init(packet_pio, packet_sm, offset,
                  BUS_D0_PIN, BUS_SCLK_PIN, BUS_CS_PIN,
                  NXTPCKT_TO_PI_PIN, 1.0416667f);

    irq_set_exclusive_handler(PIO0_IRQ_0, packet_complete_irq);
    pio_set_irq0_source_enabled(packet_pio, pis_interrupt0, true);
    irq_set_enabled(PIO0_IRQ_0, true);

    packet_dma_channel = dma_claim_unused_channel(true);
}

void dma_packet_stream_start(const uint32_t *packet_words,
                             size_t packet_count) {
    dma_channel_config config =
        dma_channel_get_default_config(packet_dma_channel);

    channel_config_set_transfer_data_size(&config, DMA_SIZE_32);
    channel_config_set_read_increment(&config, true);
    channel_config_set_write_increment(&config, false);
    channel_config_set_dreq(
        &config, pio_get_dreq(packet_pio, packet_sm, true)
    );

    completed_packets = 0u;
    pio_interrupt_clear(packet_pio, 0);

    dma_channel_configure(
        packet_dma_channel,
        &config,
        &packet_pio->txf[packet_sm],
        packet_words,
        packet_count,
        true
    );
}

void dma_packet_stream_wait(size_t packet_count) {
    uint32_t next_report = 50u;
    absolute_time_t next_debug = make_timeout_time_ms(2000);

    while (completed_packets < packet_count) {
        uint32_t completed = completed_packets;
        if (completed >= next_report) {
            printf("PACKETS_OK %lu\n", (unsigned long)next_report);
            next_report += 50u;
        }

        if (absolute_time_diff_us(get_absolute_time(), next_debug) <= 0) {
            printf(
                "DMA_DEBUG completed=%lu remaining=%lu busy=%d "
                "fifo_empty=%d fifo_full=%d pc=%u base=%u "
                "nxt=%d cs=%d sclk=%d\n",
                (unsigned long)completed,
                (unsigned long)dma_channel_hw_addr(packet_dma_channel)
                    ->transfer_count,
                dma_channel_is_busy(packet_dma_channel),
                pio_sm_is_tx_fifo_empty(packet_pio, packet_sm),
                pio_sm_is_tx_fifo_full(packet_pio, packet_sm),
                pio_sm_get_pc(packet_pio, packet_sm),
                packet_program_offset,
                gpio_get(NXTPCKT_TO_PI_PIN),
                gpio_get(BUS_CS_PIN),
                gpio_get(BUS_SCLK_PIN)
            );
            next_debug = make_timeout_time_ms(2000);
        }

        tight_loop_contents();
    }

    dma_channel_wait_for_finish_blocking(packet_dma_channel);
}
