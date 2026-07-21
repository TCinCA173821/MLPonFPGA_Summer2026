// Testbench for dualffsync
// DUT: two-flop synchronizer, sync_out is async_in delayed by 2 clocks.
`timescale 1ns/1ps
module tb_dualffsync;

    logic clk = 0, n_rst;
    logic async_in, sync_out;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    dualffsync DUT (.clk(clk), .n_rst(n_rst), .async_in(async_in), .sync_out(sync_out));

    task automatic check(input logic exp, input string msg);
        checks++;
        if (sync_out !== exp) begin
            errors++;
            $display("FAIL: %s => got %b exp %b", msg, sync_out, exp);
        end else begin
            $display("PASS: %s => %b", msg, sync_out);
        end
    endtask

    initial begin
        $dumpfile("tb_dualffsync.vcd");
        $dumpvars(0, tb_dualffsync);

        n_rst = 0; async_in = 0;
        repeat (2) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;
        check(0, "reset low");

        // Rising edge propagates after exactly 2 clocks
        async_in = 1;
        @(posedge clk); #1; check(0, "1 clk after rise (still 0)");
        @(posedge clk); #1; check(1, "2 clks after rise (now 1)");
        @(posedge clk); #1; check(1, "stays 1");

        // Falling edge propagates after 2 clocks
        async_in = 0;
        @(posedge clk); #1; check(1, "1 clk after fall (still 1)");
        @(posedge clk); #1; check(0, "2 clks after fall (now 0)");

        // Async reset forces 0 immediately
        async_in = 1; @(posedge clk); #1;
        n_rst = 0; #2; check(0, "async reset");
        n_rst = 1;

        $display("\n=== tb_dualffsync: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
