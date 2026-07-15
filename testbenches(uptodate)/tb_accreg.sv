// Testbench for accreg
// DUT: 16-bit accumulator register with priority: len (load 8-bit sign-extended)
//      > wen (load 16-bit in) > hold. Async active-low reset n_rst.
`timescale 1ns/1ps
module tb_accreg;

    logic clk = 0, n_rst;
    logic wen, len;
    logic signed [15:0] in;
    logic signed [7:0]  Lin;
    logic signed [15:0] out;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    accreg DUT (
        .clk(clk), .n_rst(n_rst), .wen(wen), .len(len),
        .in(in), .Lin(Lin), .out(out)
    );

    task automatic reset();
        n_rst = 0; wen = 0; len = 0; in = 0; Lin = 0;
        repeat (2) @(posedge clk);
        n_rst = 1;
        @(posedge clk); #1;
    endtask

    task automatic expect_out(input logic signed [15:0] exp, input string msg);
        checks++;
        if (out !== exp) begin
            errors++;
            $display("FAIL: %s => got %0d exp %0d", msg, out, exp);
        end else begin
            $display("PASS: %s = %0d", msg, out);
        end
    endtask

    initial begin
        $dumpfile("tb_accreg.vcd");
        $dumpvars(0, tb_accreg);

        reset();
        expect_out(16'sd0, "after reset");

        // Load via len (sign-extended 8-bit)
        Lin = -8'sd100; len = 1; wen = 0;
        @(posedge clk); #1; len = 0;
        expect_out(-16'sd100, "load Lin=-100 (sign extend)");

        // Write via wen
        in = 16'sd12345; wen = 1;
        @(posedge clk); #1; wen = 0;
        expect_out(16'sd12345, "write in=12345");

        // Hold when neither
        in = 16'sd999; wen = 0; len = 0;
        @(posedge clk); #1;
        expect_out(16'sd12345, "hold value");

        // len has priority over wen
        Lin = 8'sd50; in = 16'sd7; len = 1; wen = 1;
        @(posedge clk); #1; len = 0; wen = 0;
        expect_out(16'sd50, "len priority over wen");

        // Async reset mid-operation
        in = 16'sd444; wen = 1; @(posedge clk); #1;
        n_rst = 0; #2;
        expect_out(16'sd0, "async reset clears");
        n_rst = 1; wen = 0; @(posedge clk); #1;

        $display("\n=== tb_accreg: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
