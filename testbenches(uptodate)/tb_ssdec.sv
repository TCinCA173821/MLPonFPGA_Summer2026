// Testbench for ssdec (seven-segment decoder, active-high segments)
// Decodes 4-bit digit 0-9 to segment pattern; A-F -> blank (0).
`timescale 1ns/1ps
module tb_ssdec;

    logic [3:0] digit;
    logic [7:0] ss0;

    int errors = 0;
    int checks = 0;

    ssdec DUT (.digit(digit), .ss0(ss0));

    function automatic logic [7:0] model(input logic [3:0] d);
        case (d)
            4'd0: model = 8'b00111111;
            4'd1: model = 8'b00000110;
            4'd2: model = 8'b01011011;
            4'd3: model = 8'b01001111;
            4'd4: model = 8'b01100110;
            4'd5: model = 8'b01101101;
            4'd6: model = 8'b01111101;
            4'd7: model = 8'b00000111;
            4'd8: model = 8'b01111111;
            4'd9: model = 8'b01101111;
            default: model = 8'b0;
        endcase
    endfunction

    task automatic check(input logic [3:0] d);
        logic [7:0] exp;
        digit = d; #1;
        exp = model(d);
        checks++;
        if (ss0 !== exp) begin
            errors++;
            $display("FAIL: digit %0d => got %b exp %b", d, ss0, exp);
        end else begin
            $display("PASS: digit %0d => %b", d, ss0);
        end
    endtask

    initial begin
        $dumpfile("tb_ssdec.vcd");
        $dumpvars(0, tb_ssdec);

        for (int d = 0; d < 16; d++) check(d[3:0]);

        $display("\n=== tb_ssdec: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
