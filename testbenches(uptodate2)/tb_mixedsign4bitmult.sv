// Testbench for mixedsign4bitmult
// DUT: signed 4-bit * unsigned 4-bit -> sign-extended signed 16-bit product
`timescale 1ns/1ps
module tb_mixedsign4bitmult;

    logic signed [3:0] signedin1;
    logic        [3:0] unsignedin2;
    logic signed [15:0] signextendedout;

    int errors = 0;
    int checks = 0;

    mixedsign4bitmult DUT (
        .signedin1(signedin1),
        .unsignedin2(unsignedin2),
        .signextendedout(signextendedout)
    );

    task automatic check(input logic signed [3:0] a, input logic [3:0] b);
        logic signed [15:0] expected;
        signedin1   = a;
        unsignedin2 = b;
        #1;
        expected = signed'(a) * signed'({1'b0, b});
        checks++;
        if (signextendedout !== expected) begin
            errors++;
            $display("FAIL: %0d * %0d => got %0d exp %0d", a, b, signextendedout, expected);
        end else begin
            $display("PASS: %0d * %0d = %0d", a, b, signextendedout);
        end
    endtask

    initial begin
        $dumpfile("tb_mixedsign4bitmult.vcd");
        $dumpvars(0, tb_mixedsign4bitmult);

        // Exhaustive sweep over all 4-bit signed x 4-bit unsigned combinations
        for (int i = -8; i <= 7; i++)
            for (int j = 0; j <= 15; j++)
                check(i[3:0], j[3:0]);

        $display("\n=== tb_mixedsign4bitmult: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
