// Testbench for relu
// DUT: signed 16-bit -> 4-bit saturating ReLU
//   in < 0            -> 0
//   in[14:4] nonzero  -> 4'b1111 (saturate)
//   else              -> in[3:0]
`timescale 1ns/1ps
module tb_relu;

    logic signed [15:0] in;
    logic        [3:0]  out;

    int errors = 0;
    int checks = 0;

    relu DUT (.in(in), .out(out));

    function automatic logic [3:0] model(input logic signed [15:0] v);
        if (v[15]) model = 4'd0;
        else if (|v[14:4]) model = 4'b1111;
        else model = v[3:0];
    endfunction

    task automatic check(input logic signed [15:0] v);
        logic [3:0] expected;
        in = v;
        #1;
        expected = model(v);
        checks++;
        if (out !== expected) begin
            errors++;
            $display("FAIL: in=%0d => got %0d exp %0d", v, out, expected);
        end
    endtask

    initial begin
        $dumpfile("tb_relu.vcd");
        $dumpvars(0, tb_relu);

        // Directed boundary cases
        check(16'sd0);      // 0
        check(-16'sd1);     // negative -> 0
        check(16'sd15);     // 15 -> passthrough
        check(16'sd16);     // saturate -> 15
        check(16'sd7);      // 7
        check(16'sd32767);  // large positive -> 15
        check(-16'sd32768); // large negative -> 0

        // Sweep small values around the interesting region
        for (int v = -20; v <= 40; v++)
            check(v[15:0]);

        // Random
        for (int i = 0; i < 200; i++)
            check($random);

        $display("\n=== tb_relu: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
