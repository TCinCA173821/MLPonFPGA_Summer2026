module relu_tb;
  logic signed [15:0] in;
  logic [3:0] out;

  relu DUT (
    .*
  );

  int tests_passed = 0;
  int total_tests = 0;

  task test(
    input logic signed [15:0] test_in,
    input logic [3:0] expected
  );
    in = test_in;
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
    test(16'sd0, 4'b0);
    test(-16'sd10, 4'b0);
    test(16'sd15, 4'd15);
    test(16'sd16, 4'd15);
    test(16'sd6, 4'd6);
    test(16'sd2564, 4'd15);
    test(-16'sd2564, 4'd0);
    
    $display("%h/%h tests passed", tests_passed, total_tests);
    $finish;
  end
  
endmodule
