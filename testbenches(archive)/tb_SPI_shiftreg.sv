// Testbench for SPI_shiftreg
// DUT: on posedge sclk, if cs -> intreg <= {mosi, intreg[31:8]} (byte shift), else hold.
//      async active-low reset n_rst clears register. SPI_reg mirrors intreg.
`timescale 1ns/1ps
module tb_SPI_shiftreg;

    logic sclk = 0, cs, n_rst;
    logic [7:0] mosi;
    logic [31:0] SPI_reg;

    int errors = 0;
    int checks = 0;

    SPI_shiftreg DUT (
        .sclk(sclk), .cs(cs), .n_rst(n_rst), .mosi(mosi), .SPI_reg(SPI_reg)
    );

    task automatic sclk_tick();
        sclk = 0; #5;
        sclk = 1; #5;   // posedge here
        sclk = 0; #1;
    endtask

    task automatic reset();
        n_rst = 0; cs = 0; mosi = 0; sclk = 0; #7;
        n_rst = 1; #1;
    endtask

    task automatic check(input logic [31:0] exp, input string msg);
        checks++;
        if (SPI_reg !== exp) begin
            errors++;
            $display("FAIL: %s => got %h exp %h", msg, SPI_reg, exp);
        end else begin
            $display("PASS: %s => %h", msg, SPI_reg);
        end
    endtask

    task automatic shift_byte(input logic [7:0] b);
        mosi = b; cs = 1;
        sclk_tick();
    endtask

    initial begin
        $dumpfile("tb_SPI_shiftreg.vcd");
        $dumpvars(0, tb_SPI_shiftreg);

        reset();
        check(32'h0, "after reset");

        // Shift in 4 bytes; final word = {b3,b2,b1,b0}
        shift_byte(8'hAA); check(32'hAA00_0000, "byte0 AA");
        shift_byte(8'hBB); check(32'hBBAA_0000, "byte1 BB");
        shift_byte(8'hCC); check(32'hCCBB_AA00, "byte2 CC");
        shift_byte(8'hDD); check(32'hDDCC_BBAA, "byte3 DD");

        // cs low -> hold on clock edge
        mosi = 8'hFF; cs = 0;
        sclk_tick();
        check(32'hDDCC_BBAA, "cs low holds");

        // async reset mid-stream
        n_rst = 0; #2;
        check(32'h0, "async reset clears");
        n_rst = 1; #1;

        $display("\n=== tb_SPI_shiftreg: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
