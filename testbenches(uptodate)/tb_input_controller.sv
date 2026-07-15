// Testbench for input_controller
// IDLE -(Irq)-> RQ(SPI_rq) -> RECEIVING -(SPI_dv)-> BUFFER -> PULSEDONE(Id) -> IDLE
// In BUFFER, decodes SPI_d (and HLBrdata when Itype=1) into 4 signed MAC_in bytes:
//   Itype=0: MAC_in[j] = SPI_d[31-8j : 24-8j]                     (raw SPI byte)
//   Itype=1: MAC_in[j] = {SPI_d[31-8j:28-8j], HLBrdata[3-j]}       (SPI hi nibble + HLB)
`timescale 1ns/1ps
module tb_input_controller;

    logic clk = 0, n_rst;
    logic Irq, Itype, SPI_dv;
    logic [31:0] SPI_d;
    logic [3:0] HLBrdata [0:3];
    logic Id;
    logic signed [7:0] MAC_in [0:3];
    logic HLBren, HLBincr, SPI_rq;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    input_controller DUT (
        .clk(clk), .n_rst(n_rst), .Irq(Irq), .Itype(Itype), .SPI_dv(SPI_dv),
        .SPI_d(SPI_d), .HLBrdata(HLBrdata), .Id(Id), .MAC_in(MAC_in),
        .HLBren(HLBren), .HLBincr(HLBincr), .SPI_rq(SPI_rq)
    );

    task automatic reset();
        n_rst = 0; Irq = 0; Itype = 0; SPI_dv = 0; SPI_d = 0;
        for (int i = 0; i < 4; i++) HLBrdata[i] = 0;
        repeat (2) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;
    endtask

    function automatic logic [7:0] expect_byte(input int j, input logic itype);
        logic [3:0] hi;
        hi = SPI_d[31-8*j -: 4];
        if (itype) expect_byte = {hi, HLBrdata[3-j]};
        else       expect_byte = SPI_d[31-8*j -: 8];
    endfunction

    // Run one input transaction and self-check.
    task automatic transaction(input logic itype, input logic [31:0] spidat);
        logic rq_seen = 0;
        SPI_d = spidat; Itype = itype;

        // Kick off request
        Irq = 1; @(posedge clk); #1;      // IDLE -> RQ
        Irq = 0;
        if (SPI_rq) rq_seen = 1;          // RQ asserts SPI_rq
        @(posedge clk); #1;               // RQ -> RECEIVING

        // Provide data-valid
        SPI_dv = 1; @(posedge clk); #1;   // RECEIVING -> BUFFER
        SPI_dv = 0;
        @(posedge clk); #1;               // BUFFER -> PULSEDONE (MAC_in latched)

        checks++;
        if (!rq_seen) begin errors++; $display("FAIL: SPI_rq not asserted in RQ"); end
        else $display("PASS: SPI_rq asserted");

        checks++;
        if (!Id) begin errors++; $display("FAIL: Id not asserted in PULSEDONE"); end
        else $display("PASS: Id asserted");

        checks++;
        if (HLBincr !== itype) begin
            errors++; $display("FAIL: HLBincr=%b exp %b", HLBincr, itype);
        end else $display("PASS: HLBincr = %b", HLBincr);

        for (int j = 0; j < 4; j++) begin
            logic [7:0] exp;
            exp = expect_byte(j, itype);
            checks++;
            if (MAC_in[j] !== $signed(exp)) begin
                errors++;
                $display("FAIL: MAC_in[%0d] = %h exp %h (itype=%b)", j, MAC_in[j], exp, itype);
            end else $display("PASS: MAC_in[%0d] = %h", j, MAC_in[j]);
        end

        @(posedge clk); #1;               // PULSEDONE -> IDLE
    endtask

    initial begin
        $dumpfile("tb_input_controller.vcd");
        $dumpvars(0, tb_input_controller);

        reset();

        // Itype = 0 : raw SPI bytes
        transaction(1'b0, 32'hA1B2C3D4);

        // Itype = 1 : SPI high nibble concatenated with HLB read data
        HLBrdata[0] = 4'h7; HLBrdata[1] = 4'h6;
        HLBrdata[2] = 4'h5; HLBrdata[3] = 4'h4;
        transaction(1'b1, 32'h1234_5678);

        $display("\n=== tb_input_controller: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
