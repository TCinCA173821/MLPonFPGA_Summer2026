// Testbench for hidden_layer_buffer
// 4-deep bank of 4x4-bit layers. ptr advances on incr; wen writes in->mem[ptr];
// ren latches mem[ptr]->out. Async active-low reset nrst.
`timescale 1ns/1ps
module tb_hidden_layer_buffer;

    logic clk = 0, nrst;
    logic wen, ren, incr;
    logic [3:0][3:0] in;
    logic [3:0][3:0] out;

    int errors = 0;
    int checks = 0;
    logic [15:0] pat [0:3];

    always #5 clk = ~clk;

    hidden_layer_buffer DUT (
        .clk(clk), .nrst(nrst), .wen(wen), .ren(ren), .incr(incr),
        .in(in), .out(out)
    );

    task automatic reset();
        nrst = 0; wen = 0; ren = 0; incr = 0; in = '0;
        repeat (2) @(posedge clk);
        nrst = 1; @(posedge clk); #1;
    endtask

    task automatic check(input logic [15:0] exp, input string msg);
        checks++;
        if (out !== exp) begin
            errors++;
            $display("FAIL: %s => got %h exp %h", msg, out, exp);
        end else begin
            $display("PASS: %s => %h", msg, out);
        end
    endtask

    initial begin
        $dumpfile("tb_hidden_layer_buffer.vcd");
        $dumpvars(0, tb_hidden_layer_buffer);

        pat[0] = 16'h1234;
        pat[1] = 16'h5678;
        pat[2] = 16'h9ABC;
        pat[3] = 16'hDEF0;

        reset();

        // Write each of the 4 slots (ptr 0..3), advancing ptr between writes
        for (int i = 0; i < 4; i++) begin
            in = pat[i]; wen = 1; incr = 0;
            @(posedge clk); #1;             // mem[ptr=i] <= pat[i]
            wen = 0; incr = 1;
            @(posedge clk); #1;             // ptr -> i+1 (wraps to 0 after 3)
            incr = 0;
        end

        // ptr back to 0; read each slot back
        for (int i = 0; i < 4; i++) begin
            ren = 1;
            @(posedge clk); #1;             // out <= mem[ptr=i]
            ren = 0;
            check(pat[i], $sformatf("read slot %0d", i));
            incr = 1; @(posedge clk); #1; incr = 0;   // advance ptr
        end

        // Reset clears output
        ren = 1; @(posedge clk); #1; ren = 0;
        nrst = 0; #2; check(16'h0, "async reset clears out"); nrst = 1;

        $display("\n=== tb_hidden_layer_buffer: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
