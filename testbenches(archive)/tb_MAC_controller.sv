// Testbench for MAC_controller
// IDLE -(Men)-> PULLBIAS -(Id)-> LOADBIAS -> PULLINPUT -(Id)-> COMPUTE
//   COMPUTE loops back to PULLINPUT until count==Miter-1 -> PULSEDONE -> IDLE
// Outputs: Irq (pull states), MAC_l (loadbias), Itype=Lsel (pullinput), MAC_s (compute), Md (done)
`timescale 1ns/1ps
module tb_MAC_controller;

    logic clk = 0, n_rst;
    logic Men, Id, Lsel;
    logic [7:0] Miter;
    logic Md, MAC_s, MAC_l, Irq, Itype;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    MAC_controller DUT (
        .clk(clk), .n_rst(n_rst), .Men(Men), .Miter(Miter), .Id(Id), .Lsel(Lsel),
        .Md(Md), .MAC_s(MAC_s), .MAC_l(MAC_l), .Irq(Irq), .Itype(Itype)
    );

    task automatic reset();
        n_rst = 0; Men = 0; Id = 0; Lsel = 0; Miter = 0;
        repeat (2) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;
    endtask

    // Run one MAC loop with Id held; count MAC_s (compute) pulses until Md (done).
    task automatic run(input logic [7:0] miter_val, input logic sel);
        int macs = 0, macl = 0, itype_hi = 0, cyc = 0;
        logic done_seen = 0;
        Miter = miter_val; Lsel = sel; Men = 1; Id = 1;
        while (!done_seen && cyc < 200) begin
            @(posedge clk); #1;
            if (MAC_s) macs++;
            if (MAC_l) macl++;
            if (Itype) itype_hi++;
            if (Md)    done_seen = 1;
            cyc++;
        end
        Men = 0; Id = 0;
        @(posedge clk); #1;

        checks++;
        if (macs != miter_val) begin
            errors++; $display("FAIL: MAC_s pulses = %0d (exp %0d)", macs, miter_val);
        end else $display("PASS: MAC_s pulses = %0d", macs);

        checks++;
        if (macl != 1) begin
            errors++; $display("FAIL: MAC_l pulses = %0d (exp 1)", macl);
        end else $display("PASS: MAC_l pulsed once");

        checks++;
        if (!done_seen) begin
            errors++; $display("FAIL: never reached PULSEDONE");
        end else $display("PASS: reached PULSEDONE (Md)");

        checks++;
        if (sel && itype_hi == 0) begin
            errors++; $display("FAIL: Itype never asserted with Lsel=1");
        end else $display("PASS: Itype behaviour ok (Lsel=%b, itype_hi=%0d)", sel, itype_hi);
    endtask

    initial begin
        $dumpfile("tb_MAC_controller.vcd");
        $dumpvars(0, tb_MAC_controller);

        reset();
        run(8'd3, 1'b1);    // short loop, output layer (Itype should assert)
        reset();
        run(8'd5, 1'b0);    // hidden layer, Itype stays low

        $display("\n=== tb_MAC_controller: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
