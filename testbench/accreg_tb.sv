module accreg_tb;
  logic clk = 0, n_rst;
  logic wen, len;
  logic signed [15:0] in;
  logic [7:0] Lin;
  logic signed [15:0] out;

  int tests_passed = 0;
  int total_tests = 0;

  always #(10) clk++;

  accreg DUT(
    .*
  );

  task reset();
  	n_rst = '0;
  	repeat(2) @(posedge clk);
  	n_rst = '1;
  	@(posedge clk);
  	#(1);
  endtask

  task write(
    input logic [15:0] test_in
  );
	  wen = '1;
	  in = test_in;
	  $display("writing %h", in);	
	  @(posedge clk);
	  #(1);
	  wen = '0;
  endtask

  task load(
    input logic [7:0] test_bias
  );
	  len = '1;
	  Lin = test_bias;
	  $display("writing %h", Lin);	
	  @(posedge clk);
	  #(1);
	  len = '0;
  endtask

  task check(
    input logic [15:0] expected
  );
    $display("output: %h", out);
    
    total_tests++;
    if(expected == out) begin
      tests_passed++;
    end
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, accreg_tb);

  	n_rst = 1'b1;
	
  	$timeformat(-9, 2, " ns", 20);
	
  	reset();
  	@(posedge clk);
  	#(10);

    //tests
    load(-8'sd100);
    check(-16'sd100);

    write(16'sd12345);
    check(16'sd12345);

    $display("passed %h/%h tests", tests_passed, total_tests);

    $finish;
  end
endmodule
