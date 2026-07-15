`default_nettype none
// Empty top module

module top (
  // I/O ports
  input  logic hz100, reset,
  input  logic [20:0] pb,
  output logic [7:0] left, right,
         ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
  output logic red, green, blue,

  // UART ports
  output logic [7:0] txdata,
  input  logic [7:0] rxdata,
  output logic txclk, rxclk,
  input  logic txready, rxready
);

  logic start, SPI_dv, Done, MAC_s, MAC_l, HLBren, HLBincr, HLBwen, OLBincr, OLBwen, nxtpckt, ARG_s;
  logic [31:0] SPI_reg;
  logic [3:0] HLBrdata [0:3];
  logic signed [7:0] MAC_in [0:3];

  logic cs, sclk, nxtpckt_to_pi;
  logic [7:0] mosi;

  logic signed [15:0] MAC_out [0:3];
  logic [3:0] MAC_outrelu [0:3];

  logic signed [15:0] OBLrdata;
  logic [3:0] OLBrptr;

  logic [3:0] result;

  assign start = pb[9];
  assign cs = pb[10];
  assign sclk = pb[11];
  assign mosi = pb[19:12];


  assign left[0] = Done;
  assign left[1] = nxtpckt_to_pi;
  assign left[4:1] = result;
  

  controllertop main1(.*,.n_rst(!reset));
  SPI_mod spisys1(.*,.n_rst(!reset));
  genvar i;

    generate
        for (i = 0; i < WIDTH; i = i + 1) begin :
            MAC MAC_inst (.*,.n_rst(!reset),.MAC_in(MAC_in[i]),.MAC_out(MAC_out[i]),.MAC_outrelu(MAC_outrelu[i]));
        end
    endgenerate
  hidden_layer_buffer hlb1 (.*, .n_rst(!reset),.wen(HLBwen),.ren(HLBren),.incr(HLBincr),.in(MAC_outrelu),.out(HLBrdata));
  output_layer_buffer olb1 (.*,.n_rst(!reset),.wen(OLBwen),.r_inc(OLBincr),.in(MAC_out),.outdata(OBLrdata),.rptr(OLBrptr));
  argmax argmax1 (.*,.nrst(!reset),.start(ARG_s),.in(OBLrdata),.in_ptr(OLBrptr),.out(result));
  ssdec decoder1 (.digit(result),.ss0(ss0));
  
endmodule




