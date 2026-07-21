// Testbench for layer_controller
// IDLE -(Len)-> MAC -(Md)-> STORE -> (cnt==total ? DONE : MAC) ... DONE(Ld) -> IDLE
// total_layers = Lsel ? 2 : 3 ; Miter = Lsel ? 15 : 195
// STORE asserts HLBwen (hidden) or OLBwen (output); MAC asserts Men; DONE asserts Ld.
`timescale 1ns/1ps
module tb_layer_controller;

    logic clk = 0, n_rst;
    logic Len, Lsel, Md;
    logic Men, Ld, HLBwen, OLBwen;
    logic [7:0] Miter;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    layer_controller DUT (
        .clk(clk), .n_rst(n_rst), .Len(Len), .Lsel(Lsel), .Md(Md),
        .Men(Men), .Ld(Ld), .HLBwen(HLBwen), .OLBwen(OLBwen), .Miter(Miter)
    );

    task automatic reset();
        n_rst = 0; Len = 0; Lsel = 0; Md = 0;
        repeat (2) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;
    endtask

    // Run one layer sweep with Md held; count write-enable pulses until Ld (done).
    task automatic sweep(input logic sel, input int exp_writes, input logic [7:0] exp_miter);
        int hlb = 0, olb = 0, cyc = 0;
        logic done_seen = 0;
        Lsel = sel; Len = 1; Md = 1;
        while (!done_seen && cyc < 40) begin
            @(posedge clk); #1;
            if (HLBwen) hlb++;
            if (OLBwen) olb++;
            if (Ld) done_seen = 1;
            cyc++;
        end
        Len = 0; Md = 0;
        @(posedge clk); #1;

        checks++;
        if (Miter !== exp_miter) begin
            errors++; $display("FAIL: Lsel=%b Miter=%0d (exp %0d)", sel, exp_miter, exp_miter);
        end else $display("PASS: Lsel=%b Miter=%0d", sel, Miter);

        checks++;
        if (!done_seen) begin
            errors++; $display("FAIL: Lsel=%b never reached DONE", sel);
        end else $display("PASS: Lsel=%b reached DONE", sel);

        checks++;
        if (sel == 0) begin
            if (hlb != exp_writes) begin
                errors++; $display("FAIL: HLBwen pulses = %0d (exp %0d)", hlb, exp_writes);
            end else $display("PASS: HLBwen pulses = %0d", hlb);
        end else begin
            if (olb != exp_writes) begin
                errors++; $display("FAIL: OLBwen pulses = %0d (exp %0d)", olb, exp_writes);
            end else $display("PASS: OLBwen pulses = %0d", olb);
        end
    endtask

    initial begin
        $dumpfile("tb_layer_controller.vcd");
        $dumpvars(0, tb_layer_controller);

        reset();
        sweep(1'b0, 3, 8'd195);   // hidden layers: 3 stores, Miter 195
        reset();
        sweep(1'b1, 2, 8'd15);    // output layer: 2 stores, Miter 15

        $display("\n=== tb_layer_controller: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
