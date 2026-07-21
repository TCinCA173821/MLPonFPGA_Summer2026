module mainctrlfsm_tb;
logic clk = 0, n_rst;
logic start;
logic Ld;
logic Ad;
logic Len;
logic Lsel;
logic Aen;
logic Done;

mainctrlfsm DUT(.*);
always #(10) clk++;

