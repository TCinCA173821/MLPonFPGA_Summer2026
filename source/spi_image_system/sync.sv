// this module is basically 3 2ff synchronizers for sclk, cs, and mosi

module sync(
    input logic clk,
    input logic mosi_in,
    input logic cs_in,
    input logic sclk_in,
    output logic mosi_out,
    output logic cs_out,
    output logic sclk_out
);

    logic mosi_ff1, mosi_ff2;
    logic cs_ff1, cs_ff2;
    logic sclk_ff1, sclk_ff2;

    always_ff @(posedge clk) begin
        
        mosi_ff1 <= mosi_in;
        mosi_ff2 <= mosi_ff1;

        cs_ff1 <= cs_in;
        cs_ff2 <= cs_ff1;

        sclk_ff1 <= sclk_in;
        sclk_ff2 <= sclk_ff1;

    end

    assign mosi_out = mosi_ff2;
    assign cs_out = cs_ff2;
    assign sclk_out = sclk_ff2;

endmodule