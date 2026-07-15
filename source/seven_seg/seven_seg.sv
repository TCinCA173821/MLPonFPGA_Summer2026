module ssdec (
    input  logic [3:0] digit,
    output logic [7:0] ss0
);

always_comb begin
    case (digit)
        4'd0: ss0 = 8'b00111111; // 0 active high to set active low just flip every bit
        4'd1: ss0 = 8'b00000110; // 1
        4'd2: ss0 = 8'b01011011; // 2
        4'd3: ss0 = 8'b01001111; // 3
        4'd4: ss0 = 8'b01100110; // 4
        4'd5: ss0 = 8'b01101101; // 5
        4'd6: ss0 = 8'b01111101; // 6
        4'd7: ss0 = 8'b00000111; // 7
        4'd8: ss0 = 8'b01111111; // 8
        4'd9: ss0 = 8'b01101111; // 9
        default: ss0 = 8'b0;
    endcase
end

endmodule
