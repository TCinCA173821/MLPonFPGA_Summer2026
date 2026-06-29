module relu_truncate (
    input  logic        relu_en,
    input  logic signed [11:0] relu_in,
    output logic        [3:0]  relu_out
);

    always_comb begin
        relu_out = 4'b0000;

        if (relu_en) begin
            if (relu_in[11] == 1'b1)
                relu_out = 4'b0000;
            else if (|relu_in[10:3])
                relu_out = 4'b0111;
            else
                relu_out = relu_in[3:0];
        end
    end

endmodule