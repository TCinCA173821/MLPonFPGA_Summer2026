module shiftreg #(parameter width = 32) (
    input logic rst_n,
    input logic en,
    input logic clk,
    input logic [7:0]d,
    output logic [width-1:0] out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out <= 0;
        end else begin
            if(en)
                out <= {d, out[width - 1 : 8]};
            else
                out <= out;
        end
    end

endmodule
