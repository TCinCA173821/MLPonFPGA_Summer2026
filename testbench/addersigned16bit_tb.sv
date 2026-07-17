module addersigned16bit_tb;
  logic signed [15:0] in1;
  logic signed [15:0] in2;
  logic signed [15:0] out;

  addersigned16bit DUT (
    .*
  );

  int tests_passed = 0;
  int total_tests = 0;
  logic signed [15:0] expected;

  task test(
    input logic signed [15:0] a,
    input logic signed [15:0] b
  );
    in1 = a;
    in2 = b;
    expected = a + b;
    #(1);

    total_tests++;
    if(out == expected) begin
      tests_passed++;
    end
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, addersigned16bit_tb);

    //tests
    test(16'sd0, 16'sd0);
    test(16'sd100, 16'sd200);
    test(-16'sd100, 16'sd40);
    test(-16'sd100, -16'sd50);
    test(16'sd23567, -16'sd23567);
    
    $display("%d/%d tests passed", tests_passed, total_tests);

    $finish;
  end
endmodule
