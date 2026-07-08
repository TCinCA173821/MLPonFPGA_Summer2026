module spi_fsm(
    input logic rst_n
    input logic mosi_in[7:0],
    input logic cs,
    input logic sclk,
    output logic mosi_out[7:0],
    output logic shiftR,
    output logic dataValid
);
    always_ff @(posedge sclk) begin
        
    end

endmodule



////////////////////////////////this module is basically 3 2ff synchronizers for sclk, cs, and mosi//////////////////////////////////////////////////

module sync(
    input logic rst_n,
    input logic [7:0] mosi_in,
    input logic clk,
    input logic sclk_in,
    input logic cs_in,
    output logic [7:0] mosi_out,
    output logic cs_out,
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
    ff2_sync cs_ff2 (.rst_n(rst_n), .clk(clk), .in(cs_in), .out(cs_out));

    // sclk synchronization
    ff2_sync sclk_ff2 (.rst_n(rst_n), .clk(clk), .in(sclk_in), .out(sclk_out));

endmodule


/////////////////////////////////////////////2ff synchronizer//////////////////////////////////////////////////////////

module ff2_sync(
    input logic rst_n,
    input logic clk,
    input logic in,
    output logic out
);
    logic ff1, ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin   
            ff1 <= in;
            ff2 <= ff1;
        end
    end
    assign out = ff2;
endmodule



/////////////////////////////////////////shift register//////////////////////////////////////////////////////////////////

module shiftreg #(parameter width = 32) (
    input logic rst_n,
    input logic clk,
    input logic shiftR,
    input logic [7:0] in,
    output logic [width -1:0] out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out <= 0;
        else begin
            if(shiftR) 
                out <= {in, out[width - 1: 8]};
            else
                out <= out;
        end
    end

endmodule