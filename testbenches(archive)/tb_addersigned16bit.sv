// Testbench for addersigned16bit
// DUT: two signed 16-bit inputs -> signed 16-bit sum (wraps on overflow)
`timescale 1ns/1ps
module tb_addersigned16bit;

    logic signed [15:0] in1, in2, out;

    int errors = 0;
    int checks = 0;

    addersigned16bit DUT (.in1(in1), .in2(in2), .out(out));

    task automatic check(input logic signed [15:0] a, input logic signed [15:0] b);
        logic signed [15:0] expected;
        in1 = a;
        in2 = b;
        #1;
        expected = a + b;              // 16-bit two's complement, wraps
        checks++;
        if (out !== expected) begin
            errors++;
            $display("FAIL: %0d + %0d => got %0d exp %0d", a, b, out, expected);
        end
    endtask

    initial begin
        $dumpfile("tb_addersigned16bit.vcd");
        $dumpvars(0, tb_addersigned16bit);

        check(16'sd0,      16'sd0);
        check(16'sd100,    16'sd50);
        check(-16'sd100,   16'sd50);
        check(-16'sd100,  -16'sd50);
        check(16'sd32767,  16'sd1);      // positive overflow -> wraps
        check(-16'sd32768,-16'sd1);      // negative overflow -> wraps
        check(16'sd12345, -16'sd12345);

        // Random directed sweep
        for (int i = 0; i < 200; i++)
            check($random, $random);

        $display("\n=== tb_addersigned16bit: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
