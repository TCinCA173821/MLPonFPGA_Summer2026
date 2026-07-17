#ifndef SEND_PACKET_H
#define SEND_PACKET_H

/* Configure D[7:0], chip select, and SCLK as Pico outputs. */
void send_packet_init(void);

/* Send the four bytes currently stored in global pkt[] to the FPGA. */
void send_packet(void);

#endif
