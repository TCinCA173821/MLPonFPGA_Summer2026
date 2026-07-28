`timescale 1ns/1ps

module tb_spi_packet_chain;
    logic clk = 1'b0;
    logic sclk = 1'b0;
    logic n_rst = 1'b0;
    logic cs = 1'b0;
    logic [7:0] mosi = 8'h00;

    logic Men = 1'b1;
    logic [7:0] Miter = 8'd195;
    logic Lsel = 1'b0;
    logic [15:0] HLBrdata = 16'h0000;

    logic Md;
    logic MAC_s;
    logic MAC_l;
    logic Irq;
    logic Itype;
    logic Id;
    logic [31:0] MAC_in;
    logic HLBren;
    logic HLBincr;
    logic SPI_rq;

    logic nxtpckt_to_pi;
    logic SPI_dv;
    logic [31:0] SPI_reg;

    logic saw_spi_dv = 1'b0;
    logic saw_id = 1'b0;

    /* Approximate the FPGA's 27 MHz system clock. */
    always #19 clk = ~clk;

    SPI_mod dut_spi (
        .clk(clk),
        .n_rst(n_rst),
        .nxtpckt(SPI_rq),
        .cs(cs),
        .sclk(sclk),
        .mosi(mosi),
        .nxtpckt_to_pi(nxtpckt_to_pi),
        .SPI_dv(SPI_dv),
        .SPI_reg(SPI_reg)
    );

    input_controller dut_input (
        .clk(clk),
        .n_rst(n_rst),
        .Irq(Irq),
        .Itype(Itype),
        .SPI_dv(SPI_dv),
        .SPI_d(SPI_reg),
        .HLBrdata(HLBrdata),
        .Id(Id),
        .MAC_in(MAC_in),
        .HLBren(HLBren),
        .HLBincr(HLBincr),
        .SPI_rq(SPI_rq)
    );

    MAC_controller dut_mac (
        .clk(clk),
        .n_rst(n_rst),
        .Men(Men),
        .Miter(Miter),
        .Id(Id),
        .Lsel(Lsel),
        .Md(Md),
        .MAC_s(MAC_s),
        .MAC_l(MAC_l),
        .Irq(Irq),
        .Itype(Itype)
    );

    always @(posedge clk) begin
        if (SPI_dv) saw_spi_dv <= 1'b1;
        if (Id) saw_id <= 1'b1;
    end

    task automatic send_byte(input logic [7:0] value);
        begin
            mosi = value;
            #200;
            sclk = 1'b1;
            #200;
            sclk = 1'b0;
            #200;
        end
    endtask

    initial begin
        $dumpfile("tb_spi_packet_chain.vcd");
        $dumpvars(0, tb_spi_packet_chain);

        repeat (5) @(posedge clk);
        n_rst = 1'b1;

        fork
            begin
                wait (nxtpckt_to_pi === 1'b1);
            end
            begin
                repeat (100) @(posedge clk);
                $fatal(1, "Timeout waiting for first NXTPCKT");
            end
        join_any
        disable fork;

        $display("FIRST_REQUEST_OK");

        cs = 1'b1;
        send_byte(8'h11);
        send_byte(8'h22);
        send_byte(8'h33);
        send_byte(8'h44);

        fork
            begin
                wait (nxtpckt_to_pi === 1'b0);
            end
            begin
                repeat (100) @(posedge clk);
                $fatal(1, "Timeout waiting for first NXTPCKT acknowledgment");
            end
        join_any
        disable fork;

        cs = 1'b0;
        $display("FIRST_PACKET_OK");

        fork
            begin
                wait (nxtpckt_to_pi === 1'b1);
            end
            begin
                repeat (200) @(posedge clk);
                if (!saw_spi_dv) $fatal(1, "SPI_dv was never generated");
                if (!saw_id) $fatal(1, "Id was never generated");
                $fatal(1, "Controller never generated the second NXTPCKT");
            end
        join_any
        disable fork;

        if (!saw_spi_dv) $fatal(1, "Second request arrived without observing SPI_dv");
        if (!saw_id) $fatal(1, "Second request arrived without observing Id");

        $display("SECOND_REQUEST_OK");
        $display("PASS: packet 1 advanced through SPI_dv and Id to packet 2 request");
        $finish;
    end
endmodule
