// Testbench for SPI_mod (shift register + cs synchronizer + control FSM)
// Drives a full packet transaction: request -> chip-select -> 4 byte shifts ->
// deassert cs, and checks the captured 32-bit word and the SPI_dv data-valid pulse.
`timescale 1ns/1ps
module tb_SPI_mod;

    logic clk = 0, n_rst;
    logic nxtpckt, cs, sclk;
    logic [7:0] mosi;
    logic nxtpckt_to_pi, SPI_dv;
    logic [31:0] SPI_reg;

    int errors = 0;
    int checks = 0;
    logic saw_rq = 0, saw_dv = 0;

    always #5 clk = ~clk;

    // latch transient one-cycle outputs
    always @(posedge clk) begin
        if (nxtpckt_to_pi) saw_rq <= 1;
        if (SPI_dv)        saw_dv <= 1;
    end

    SPI_mod DUT (
        .clk(clk), .n_rst(n_rst), .nxtpckt(nxtpckt), .cs(cs), .sclk(sclk),
        .mosi(mosi), .nxtpckt_to_pi(nxtpckt_to_pi), .SPI_dv(SPI_dv), .SPI_reg(SPI_reg)
    );

    task automatic sclk_tick();
        sclk = 0; @(posedge clk);
        sclk = 1; @(posedge clk); @(posedge clk);  // posedge sclk captured
        sclk = 0; @(posedge clk);
    endtask

    task automatic check(input logic cond, input string msg);
        checks++;
        if (!cond) begin errors++; $display("FAIL: %s", msg); end
        else       $display("PASS: %s", msg);
    endtask

    initial begin
        $dumpfile("tb_SPI_mod.vcd");
        $dumpvars(0, tb_SPI_mod);

        n_rst = 0; nxtpckt = 0; cs = 0; sclk = 0; mosi = 0;
        repeat (3) @(posedge clk);
        n_rst = 1; @(posedge clk); #1;
        check(SPI_reg == 32'h0, "reset clears SPI_reg");

        // Request a packet (one-cycle pulse)
        nxtpckt = 1; @(posedge clk); #1; nxtpckt = 0;
        repeat (2) @(posedge clk);
        check(saw_rq, "nxtpckt_to_pi asserted after request");

        // Assert chip select, allow synchronizer to propagate
        cs = 1;
        repeat (3) @(posedge clk);

        // Shift in four bytes
        mosi = 8'h11; sclk_tick();
        mosi = 8'h22; sclk_tick();
        mosi = 8'h33; sclk_tick();
        mosi = 8'h44; sclk_tick();
        check(SPI_reg == 32'h4433_2211, "captured word = {b3,b2,b1,b0}");

        // Deassert cs -> FSM should pulse data valid
        cs = 0;
        repeat (6) @(posedge clk);
        check(saw_dv, "SPI_dv pulsed after cs deasserted");

        $display("\n=== tb_SPI_mod: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
