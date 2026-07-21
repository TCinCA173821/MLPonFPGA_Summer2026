// Testbench for argmax
// Streaming max-tracker: while start, if in > out_reg then out_reg<=in, out<=in_ptr.
// out_reg resets to 0, so out is the pointer of the running (strict) maximum.
`timescale 1ns/1ps
module tb_argmax;

    logic clk = 0, nrst;
    logic start;
    logic [15:0] in;
    logic [3:0]  in_ptr;
    logic [3:0]  out;

    int errors = 0;
    int checks = 0;

    always #5 clk = ~clk;

    argmax DUT (
        .clk(clk), .nrst(nrst), .start(start),
        .in(in), .in_ptr(in_ptr), .out(out)
    );

    task automatic reset();
        nrst = 0; start = 0; in = 0; in_ptr = 0;
        repeat (2) @(posedge clk);
        nrst = 1; @(posedge clk); #1;
    endtask

    // Stream a 10-element vector and check argmax pointer
    task automatic run_vector(input logic [15:0] data [0:9], input logic [3:0] exp);
        logic [15:0] best; logic [3:0] best_ptr;
        best = 0; best_ptr = 0;
        for (int i = 0; i < 10; i++) begin
            start = 1; in = data[i]; in_ptr = i[3:0];
            if (data[i] > best) begin best = data[i]; best_ptr = i[3:0]; end
            @(posedge clk); #1;
        end
        start = 0; @(posedge clk); #1;
        checks++;
        if (out !== exp || out !== best_ptr) begin
            errors++;
            $display("FAIL: argmax => got ptr %0d, model %0d, exp %0d", out, best_ptr, exp);
        end else begin
            $display("PASS: argmax ptr = %0d", out);
        end
    endtask

    logic [15:0] v [0:9];

    initial begin
        $dumpfile("tb_argmax.vcd");
        $dumpvars(0, tb_argmax);

        reset();

        // Max is 4050 at index 3
        v = '{123, 456, 223, 4050, 932, 123, 764, 384, 523, 523};
        run_vector(v, 4'd3);

        // Max at index 9
        reset();
        v = '{10, 20, 30, 40, 50, 60, 70, 80, 90, 100};
        run_vector(v, 4'd9);

        // Max at index 0 (ties resolve to first via strict >)
        reset();
        v = '{5000, 5000, 100, 100, 100, 100, 100, 100, 100, 100};
        run_vector(v, 4'd0);

        // Random vectors
        for (int t = 0; t < 5; t++) begin
            reset();
            for (int i = 0; i < 10; i++) v[i] = $random;
            begin
                logic [15:0] best; logic [3:0] bp; best = 0; bp = 0;
                for (int i = 0; i < 10; i++)
                    if (v[i] > best) begin best = v[i]; bp = i[3:0]; end
                run_vector(v, bp);
            end
        end

        $display("\n=== tb_argmax: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
