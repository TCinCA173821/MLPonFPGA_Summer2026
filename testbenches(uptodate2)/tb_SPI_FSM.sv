// Testbench for SPI_FSM
// States: IDLE -> (nxtpckt) RQ -> (sync_cs) RECEIVE -> (!sync_cs) PULSEDV -> IDLE
// Outputs: nxtpckt_to_pi=1 in RQ, SPI_dv=1 in PULSEDV
`timescale 1ns/1ps
module tb_SPI_FSM;

    logic clk = 0, n_rst;
    logic sync_cs, nxtpckt;
    logic nxtpckt_to_pi, SPI_dv;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    SPI_FSM DUT (
        .clk(clk), .n_rst(n_rst), .sync_cs(sync_cs), .nxtpckt(nxtpckt),
        .nxtpckt_to_pi(nxtpckt_to_pi), .SPI_dv(SPI_dv)
    );

    task automatic reset();
        n_rst = 0; sync_cs = 0; nxtpckt = 0;
        repeat (2) @(posedge clk);
        n_rst = 1;
        @(posedge clk); #1;
    endtask

    task automatic check(input logic exp_rq, input logic exp_dv, input string msg);
        checks++;
        if (nxtpckt_to_pi !== exp_rq || SPI_dv !== exp_dv) begin
            errors++;
            $display("FAIL: %s => rq=%b dv=%b exp rq=%b dv=%b",
                     msg, nxtpckt_to_pi, SPI_dv, exp_rq, exp_dv);
        end else begin
            $display("PASS: %s => rq=%b dv=%b", msg, nxtpckt_to_pi, SPI_dv);
        end
    endtask

    initial begin
        $dumpfile("tb_SPI_FSM.vcd");
        $dumpvars(0, tb_SPI_FSM);

        reset();
        check(0, 0, "IDLE");

        // Request a packet
        nxtpckt = 1;
        @(posedge clk); #1;         // now in RQ
        nxtpckt = 0;
        check(1, 0, "RQ asserts nxtpckt_to_pi");

        // Assert chip select -> move to RECEIVE
        sync_cs = 1;
        @(posedge clk); #1;
        check(0, 0, "RECEIVE (cs high)");

        // Hold cs -> stay in RECEIVE
        @(posedge clk); #1;
        check(0, 0, "RECEIVE holds while cs high");

        // Deassert cs -> PULSEDV
        sync_cs = 0;
        @(posedge clk); #1;
        check(0, 1, "PULSEDV asserts SPI_dv");

        // Auto return to IDLE
        @(posedge clk); #1;
        check(0, 0, "back to IDLE");

        $display("\n=== tb_SPI_FSM: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
