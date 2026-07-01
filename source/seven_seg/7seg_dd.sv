// top.sv
// Write your top file below
`default_nettype none

// !NOTES! Need to know:
// Active high or low?
// bit - seg arrangement

module seven_segment_display (
    input  logic [3:0] digit,
    output logic [7:0] ss0
);

always_comb begin
    case (digit)
        4'd0: ss0 = 8'bXXXXXXXX;
        4'd1: ss0 = 8'bXXXXXXXX;
        4'd2: ss0 = 8'bXXXXXXXX;
        4'd3: ss0 = 8'bXXXXXXXX;
        4'd4: ss0 = 8'bXXXXXXXX;
        4'd5: ss0 = 8'bXXXXXXXX;
        4'd6: ss0 = 8'bXXXXXXXX;
        4'd7: ss0 = 8'bXXXXXXXX;
        4'd8: ss0 = 8'bXXXXXXXX;
        4'd9: ss0 = 8'bXXXXXXXX;
        default: ss0 = 8'bXXXXXXXX;
    endcase
end

endmodule
