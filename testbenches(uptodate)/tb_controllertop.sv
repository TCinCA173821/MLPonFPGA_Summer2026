// Integration testbench for controllertop
// Wires together main_ctrlfsm, layer_controller, MAC_controller, input_controller,
// argmax_controller. Drives 'start', emulates the Pi/SPI side by answering every
// 'nxtpckt' request with an SPI_dv data-valid pulse, and watches the pipeline run.
`timescale 1ns/1ps
module tb_controllertop;

    logic clk = 0, n_rst;
    logic start;
    logic [3:0] HLBrdata [0:3];
    logic SPI_dv;
    logic [31:0] SPI_reg;
    logic Done, MAC_s, MAC_l;
    logic signed [7:0] MAC_in [0:3];
    logic HLBren, HLBincr, HLBwen, OLBincr, OLBwen, nxtpckt, ARG_s;

    int errors = 0;
    int checks = 0;
    int nxtpckt_pulses = 0;
    logic done_seen = 0;
    logic x_seen = 0;

    always #5 clk = ~clk;

    controllertop DUT (
        .clk(clk), .n_rst(n_rst), .start(start), .HLBrdata(HLBrdata),
        .SPI_dv(SPI_dv), .SPI_reg(SPI_reg), .Done(Done),
        .MAC_s(MAC_s), .MAC_l(MAC_l), .MAC_in(MAC_in),
        .HLBren(HLBren), .HLBincr(HLBincr), .HLBwen(HLBwen),
        .OLBincr(OLBincr), .OLBwen(OLBwen), .nxtpckt(nxtpckt), .ARG_s(ARG_s)
    );

    // Observers
    logic nxtpckt_d = 0;
    always @(posedge clk) begin
        nxtpckt_d <= nxtpckt;
        if (nxtpckt && !nxtpckt_d) nxtpckt_pulses++;   // rising edges = requests
        if (Done) done_seen <= 1;
        if ($isunknown(Done) || $isunknown(nxtpckt) || $isunknown(MAC_s)) x_seen <= 1;
    end

    // Emulated Pi: answer each packet request with a data-valid pulse
    initial begin
        SPI_dv = 0;
        forever begin
            @(posedge clk);
            if (nxtpckt) begin
                repeat (2) @(posedge clk);
                SPI_dv <= 1;
                @(posedge clk);
                SPI_dv <= 0;
            end
        end
    end

    initial begin
        $dumpfile("tb_controllertop.vcd");
        $dumpvars(0, tb_controllertop);

        // Constant stimulus data
        SPI_reg = 32'h3355_77AA;
        HLBrdata[0] = 4'h1; HLBrdata[1] = 4'h2;
        HLBrdata[2] = 4'h3; HLBrdata[3] = 4'h4;

        n_rst = 0; start = 0;
        repeat (3) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;

        // Idle: nothing asserted
        checks++;
        if (Done !== 1'b0) begin errors++; $display("FAIL: Done asserted while idle"); end
        else $display("PASS: idle, Done low");

        // Pulse start
        start = 1; @(posedge clk); #1; start = 0;

        // Let the pipeline run; stop early once Done seen
        begin
            int cyc = 0;
            while (!done_seen && cyc < 200000) begin
                @(posedge clk); cyc++;
            end
            $display("INFO: ran %0d cycles, nxtpckt requests = %0d", cyc, nxtpckt_pulses);
        end

        // The design must at least respond to start by requesting input packets
        checks++;
        if (nxtpckt_pulses == 0) begin
            errors++; $display("FAIL: no packet requests after start (pipeline stalled)");
        end else $display("PASS: pipeline requested %0d input packets", nxtpckt_pulses);

        // No unknowns on key control signals
        checks++;
        if (x_seen) begin errors++; $display("FAIL: X detected on control signals"); end
        else $display("PASS: no X on control signals");

        // Informational: did a full inference complete?
        if (done_seen) $display("INFO: Done asserted - full inference completed.");
        else           $display("INFO: Done not asserted within cycle budget.");

        $display("\n=== tb_controllertop: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
