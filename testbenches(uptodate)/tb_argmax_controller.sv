// Testbench for argmax_controller
// IDLE -(Aen)-> RUN -> INCR -> (node==9 ? DONE : RUN) ... DONE -> IDLE
// Outputs: ARG_s pulses in RUN (x10), OLBincr pulses in INCR (x10), Ad in DONE.
`timescale 1ns/1ps
module tb_argmax_controller;

    logic clk = 0, n_rst;
    logic Aen;
    logic Ad, OLBincr, ARG_s;

    int errors = 0;
    int checks = 0;
    int arg_s_count = 0, olb_count = 0, ad_count = 0;

    always #5 clk = ~clk;

    argmax_controller DUT (
        .clk(clk), .n_rst(n_rst), .Aen(Aen),
        .Ad(Ad), .OLBincr(OLBincr), .ARG_s(ARG_s)
    );

    // count output pulses each cycle
    always @(posedge clk) begin
        if (ARG_s)   arg_s_count++;
        if (OLBincr) olb_count++;
        if (Ad)      ad_count++;
    end

    initial begin
        $dumpfile("tb_argmax_controller.vcd");
        $dumpvars(0, tb_argmax_controller);

        n_rst = 0; Aen = 0;
        repeat (2) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;

        // Kick off one argmax sweep
        Aen = 1; @(posedge clk); #1; Aen = 0;

        // Run until Ad seen (10 RUN/INCR pairs) with timeout guard
        begin
            int cyc = 0;
            while (ad_count == 0 && cyc < 60) begin
                @(posedge clk); #1; cyc++;
            end
        end

        checks++;
        if (arg_s_count != 10) begin
            errors++; $display("FAIL: ARG_s pulses = %0d (exp 10)", arg_s_count);
        end else $display("PASS: ARG_s pulsed 10 times");

        checks++;
        if (olb_count != 10) begin
            errors++; $display("FAIL: OLBincr pulses = %0d (exp 10)", olb_count);
        end else $display("PASS: OLBincr pulsed 10 times");

        checks++;
        if (ad_count != 1) begin
            errors++; $display("FAIL: Ad pulses = %0d (exp 1)", ad_count);
        end else $display("PASS: Ad pulsed once (done)");

        $display("\n=== tb_argmax_controller: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
