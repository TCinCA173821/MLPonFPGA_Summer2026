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

