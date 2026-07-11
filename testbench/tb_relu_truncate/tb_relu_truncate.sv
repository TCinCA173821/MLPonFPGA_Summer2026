module tb_relu_truncate;

//tb signals
logic relu_en;
logic signed [11:0] relu_in;
logic [3:0] relu_out;

//tests
int tests_passed = 0;
int tests_total = 0;

relu_truncate DUT(
    .relu_en(relu_en), 
    .relu_in(relu_in),
    .relu_out(relu_out)
);

task test(
    input logic test_en,
    input logic signed [11:0] test_in,
    input logic [3:0] expected_out
);
    relu_en = test_en;
    relu_in = test_in;
    #(1);

    tests_total++;

    $display(
        "relu_en = %b, relu_in = %0d, relu_out = %0d, 
        expected = %0d", relu_en, relu_in, relu_out, expected_out
    );

    if(relu_out == expected_out) begin
        tests_passed++;
        $display("PASS\n");
    end
    else begin
        $display("FAIL\n");
    end
endtask

initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, tb_relu_truncate);

    $timeformat(-9, 2, " ns", 20);

    //initialize inputs
    relu_en = 1'b0;
    relu_in = 12'sd0;
    #(1);

    //relu not actived --> output = 0
    test(1'b0, 12'sd5, 4'd0);
    test(1'b0, -12'sd5, 4'd0);

    //negative input --> output = 0
    test(1'b1, -12'sd1, 4'd0);
    test(1'b1, -12'sd8, 4'd0);
    test(1'b1, -12'sd100, 4'd0);
    test(1'b1, -12'sd2048, 4'd0);

    //input 0 through 7 inclusive --> output = input
    test(1'b1, 12'sd0, 4'd0);
    test(1'b1, 12'sd1, 4'd1);
    test(1'b1, 12'sd2, 4'd2);
    test(1'b1, 12'sd7, 4'd7);

    //input greater than 7 --> output = 7
    test(1'b1, 12'sd8, 4'd7);
    test(1'b1, 12'sd15, 4'd7);
    test(1'b1, 12'sd100, 4'd7);
    test(1'b1, 12'sd2047, 4'd7);

    $display("Tests passed: %0d/%0d", tests_passed, tests_total);

    if (tests_passed == tests_total) begin
        $display("All tests passed!");
    end
    else begin
        $display("Some tests failed.");
    end

    $finish;
end

endmodule
