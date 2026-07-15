// Testbench for main_ctrlfsm
// IDLE -(start)-> HIDDENLAYER -(Ld)-> OUTPUTLAYER -(Ld)-> ARGMAX -(Ad)-> PULSEDONE -> IDLE
// Outputs: Len (hidden & output), Lsel (output only), Aen (argmax), Done (pulsedone)
`timescale 1ns/1ps
module tb_main_ctrlfsm;

    logic clk = 0, n_rst;
    logic start, Ld, Ad;
    logic Len, Lsel, Aen, Done;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    main_ctrlfsm DUT (
        .clk(clk), .n_rst(n_rst), .start(start), .Ld(Ld), .Ad(Ad),
        .Len(Len), .Lsel(Lsel), .Aen(Aen), .Done(Done)
    );

    task automatic reset();
        n_rst = 0; start = 0; Ld = 0; Ad = 0;
        repeat (2) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;
    endtask

    task automatic check(input logic eLen, eLsel, eAen, eDone, input string msg);
        checks++;
        if (Len!==eLen || Lsel!==eLsel || Aen!==eAen || Done!==eDone) begin
            errors++;
            $display("FAIL: %s => Len=%b Lsel=%b Aen=%b Done=%b (exp %b %b %b %b)",
                     msg, Len, Lsel, Aen, Done, eLen, eLsel, eAen, eDone);
        end else $display("PASS: %s", msg);
    endtask

    initial begin
        $dumpfile("tb_main_ctrlfsm.vcd");
        $dumpvars(0, tb_main_ctrlfsm);

        reset();
        check(0,0,0,0, "IDLE");

        // start -> HIDDENLAYER (Len only)
        start = 1; @(posedge clk); #1; start = 0;
        check(1,0,0,0, "HIDDENLAYER: Len");

        // stays until Ld
        @(posedge clk); #1;
        check(1,0,0,0, "HIDDENLAYER holds");

        // Ld -> OUTPUTLAYER (Len + Lsel)
        Ld = 1; @(posedge clk); #1; Ld = 0;
        check(1,1,0,0, "OUTPUTLAYER: Len+Lsel");

        // Ld -> ARGMAX (Aen)
        Ld = 1; @(posedge clk); #1; Ld = 0;
        check(0,0,1,0, "ARGMAX: Aen");

        // stays until Ad
        @(posedge clk); #1;
        check(0,0,1,0, "ARGMAX holds");

        // Ad -> PULSEDONE (Done)
        Ad = 1; @(posedge clk); #1; Ad = 0;
        check(0,0,0,1, "PULSEDONE: Done");

        // back to IDLE
        @(posedge clk); #1;
        check(0,0,0,0, "back to IDLE");

        $display("\n=== tb_main_ctrlfsm: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
