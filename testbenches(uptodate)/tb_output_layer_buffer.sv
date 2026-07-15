// Testbench for output_layer_buffer
// 12-entry 16-bit register file. Each wen writes 4 entries at wptr (wptr: 0->4->8->0).
//   reg[wptr+0]=in[3], +1=in[2], +2=in[1], +3=in[0].
// r_inc advances rptr (0..9 then wraps). out_data = reg[rptr] (combinational).
`timescale 1ns/1ps
module tb_output_layer_buffer;

    logic clk = 0, nrst;
    logic wen, r_inc;
    logic [3:0][15:0] in;
    logic [15:0] out_data;
    logic [3:0] rptr;

    int errors = 0;
    int checks = 0;
    logic [15:0] expected [0:11];

    always #5 clk = ~clk;

    output_layer_buffer DUT (
        .clk(clk), .nrst(nrst), .wen(wen), .r_inc(r_inc),
        .in(in), .out_data(out_data), .rptr(rptr)
    );

    task automatic reset();
        nrst = 0; wen = 0; r_inc = 0; in = '0;
        repeat (2) @(posedge clk);
        nrst = 1; @(posedge clk); #1;
    endtask

    initial begin
        $dumpfile("tb_output_layer_buffer.vcd");
        $dumpvars(0, tb_output_layer_buffer);

        for (int k = 0; k < 12; k++) expected[k] = 16'h1000 + k;

        reset();

        // Three writes fill entries 0..11 (wptr 0,4,8)
        for (int b = 0; b < 3; b++) begin
            in[3] = expected[4*b + 0];
            in[2] = expected[4*b + 1];
            in[1] = expected[4*b + 2];
            in[0] = expected[4*b + 3];
            wen = 1;
            @(posedge clk); #1;
            wen = 0;
        end

        // Read entries 0..9 via rptr, checking combinational out_data
        for (int k = 0; k < 10; k++) begin
            checks++;
            if (out_data !== expected[k]) begin
                errors++;
                $display("FAIL: read idx %0d (rptr=%0d) => got %h exp %h",
                         k, rptr, out_data, expected[k]);
            end else begin
                $display("PASS: read idx %0d => %h", k, out_data);
            end
            r_inc = 1; @(posedge clk); #1; r_inc = 0;
        end

        // After 9 increments-from-0 plus wrap check: rptr should have wrapped at 9->0
        checks++;
        if (rptr !== 4'd0) begin
            errors++;
            $display("FAIL: rptr wrap => got %0d exp 0", rptr);
        end else $display("PASS: rptr wrapped to 0");

        $display("\n=== tb_output_layer_buffer: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
