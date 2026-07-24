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
  logic [15:0] HLBrdata;
  logic [31:0] MAC_in;

  logic cs, sclk, nxtpckt_to_pi;
  logic [7:0] mosi;

  logic [63:0] MAC_out;
  logic [15:0] MAC_outrelu;

  logic [15:0] OLBrdata;
  logic [3:0] OLBrptr;

  logic [3:0] result;
  logic clk;

  assign clk = hz100;

  assign start = pb[9];
  assign cs = pb[10];
  assign sclk = pb[11];
  assign mosi = pb[19:12];


  assign left[0] = Done;
  assign left[1] = nxtpckt_to_pi;
  assign left[5:2] = result;
  

  controllertop main1(.*,.n_rst(!reset));
  SPI_mod spisys1(.*,.n_rst(!reset));
  genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_mac
          MAC MAC_inst (.*,.n_rst(!reset),.MAC_in(MAC_in[8*i +:8]),.MAC_out(MAC_out[16*i +:16]),.MAC_outrelu(MAC_outrelu[4*i +:4]));
        end
    endgenerate
  hidden_layer_buffer hlb1 (.*, .nrst(!reset),.wen(HLBwen),.ren(HLBren),.incr(HLBincr),.in(MAC_outrelu),.out(HLBrdata));
  output_layer_buffer olb1 (.*,.nrst(!reset),.wen(OLBwen),.r_inc(OLBincr),.in(MAC_out),.out_data(OLBrdata),.rptr(OLBrptr));
  argmax argmax1 (.*,.nrst(!reset),.start(ARG_s),.in(OLBrdata),.in_ptr(OLBrptr),.out(result));
  ssdec decoder1 (.digit(result),.ss0(ss0));
  
endmodule
