// this module is basically 3 2ff synchronizers for sclk, cs, and mosi

module sync(
    input logic rst_n,
    input logic clk,
    input logic [7:0] mosi_in,
    output logic [7:0] mosi_out,
    input logic cs_in,
    output logic cs_out,
    input logic sclk_in,
    output logic sclk_out
);
    //mosi[7:0] synchronization (mosi_sync)
    genvar i;
    generate
        for(i=0; i < 8; i++) begin : mosi_sync
            ff2_sync mosi_ff2 (.rst_n(rst_n), .clk(clk), .in(mosi_in[i]), .out(mosi_out[i]));
        end
    endgenerate

    //cs synchronization
    ff2_sync cs_ff2 (.rst_n(rst_n), clk(clk), .in(cs_in), .out(cs_out));

    // sclk synchronization
    ff2_sync sclk_ff2 (.rst_n(rst_n), clk(clk), .in(sclk_in), .out(sclk_out));

endmodule