
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