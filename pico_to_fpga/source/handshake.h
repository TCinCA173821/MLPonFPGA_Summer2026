#ifndef HANDSHAKE_H
#define HANDSHAKE_H

/* Configure START as an output and NXTPCKT as an input. */
void handshake_init(void);

/* Pulse START high once the Pico has a complete image ready for inference. */
void send_start(void);

/* Block until the FPGA raises its active-high request for another packet. */
void wait_for_next_packet(void);

/* Block until that request returns low, preventing duplicate transmissions. */
void wait_for_next_packet_end(void);

#endif
