module shiftreg #(parameter width = 8) (
    input logic rst_n,
    input logic en,
    input logic clk,
    input logic dir,
    input logic d,
    output logic [width-1:0] out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out <= 0;
        end else begin
            if(en)
                case(dir)
                    0: out <= {out[width-2:0], d};
                    1: out <= {d, out[width - 1 : 1]};
                endcase
            else
                out <= out;
        end
    end

endmodule