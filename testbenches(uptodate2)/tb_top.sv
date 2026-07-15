// Testbench for top (full FPGA top level)
// NOTE: source/top.sv is currently a work-in-progress and does not yet elaborate
// cleanly (undefined WIDTH parameter, missing clock net, packed/unpacked port
// mismatches, .outdata vs .out_data). This testbench documents the intended
// stimulus for the top-level once those are resolved. It drives hz100 as the
// system clock and exercises reset plus the SPI push-button mapping.
`timescale 1ns/1ps
module tb_top;

    logic hz100 = 0, reset;
    logic [20:0] pb;
    logic [7:0] left, right, ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0;
    logic red, green, blue;
    logic [7:0] txdata;
    logic [7:0] rxdata;
    logic txclk, rxclk;
    logic txready, rxready;

    int errors = 0;
    int checks = 0;

    always #5 hz100 = ~hz100;

    top DUT (
        .hz100(hz100), .reset(reset), .pb(pb),
        .left(left), .right(right),
        .ss7(ss7), .ss6(ss6), .ss5(ss5), .ss4(ss4),
        .ss3(ss3), .ss2(ss2), .ss1(ss1), .ss0(ss0),
        .red(red), .green(green), .blue(blue),
        .txdata(txdata), .rxdata(rxdata),
        .txclk(txclk), .rxclk(rxclk),
        .txready(txready), .rxready(rxready)
    );

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        pb = '0; rxdata = '0; txready = 0; rxready = 0;

        // Reset
        reset = 1;
        repeat (4) @(posedge hz100);
        reset = 0;
        @(posedge hz100); #1;

        // ss0 should be a valid seven-seg pattern after reset (result = 0)
        checks++;
        if ($isunknown(ss0)) begin errors++; $display("FAIL: ss0 unknown after reset"); end
        else $display("PASS: ss0 = %b after reset", ss0);

        // Pulse start via pb[9]
        pb[9] = 1; @(posedge hz100); #1; pb[9] = 0;

        // Drive a few SPI clocks via pb[11], cs via pb[10], data via pb[19:12]
        pb[10] = 1;                       // cs
        for (int i = 0; i < 4; i++) begin
            pb[19:12] = 8'hA0 + i;        // mosi byte
            pb[11] = 1; @(posedge hz100);
            pb[11] = 0; @(posedge hz100);
        end
        pb[10] = 0;

        repeat (20) @(posedge hz100);

        $display("\n=== tb_top: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
