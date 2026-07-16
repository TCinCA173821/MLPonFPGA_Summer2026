module argmax_tb;

//tb signals
logic clk = 0, nrst;
logic start;
logic signed [15:0] in;
logic [3:0] in_ptr;
logic [3:0] out;

//tests
int tests_passed = 0;
int total_tests = 0;
logic [15:0] dataset [0:9];
logic [3:0] data_cnt;

always #(10) clk++;

argmax DUT(
	.*
);

task reset();
	nrst = '0;
	repeat(2) @(posedge clk);
	nrst = '1;
	@(posedge clk);
	#(1);
endtask

task start_arg(
	logic [15:0] test_val,
	logic [3:0] test_ptr
);
	start = '0;
	in = test_val;
	in_ptr = test_ptr;
	repeat(2) @(posedge clk);
	start = '1;
	@(posedge clk);
	#(1);
endtask

task check(
	logic[3:0] expected
);
	$display("out: %h, expected: %h", out, expected);	
	total_tests++;	
	if(expected == out) begin
		tests_passed++;
	end
endtask

initial begin
	$dumpfile("waveform.fst");
	$dumpvars(0, tb_circ_shiftreg);

	nrst = 1'b1;
	
	$timeformat(-9, 2, " ns", 20);
	
	reset();
	@(posedge clk);
	#(10);

	//tests
	dataset = '{123, 456, 223, 4050, 932, 123, 764, 384, 523, 523};
	for(int i = 0; i < 10; i++) begin
		start_arg(dataset[i], 4'(i));
	end
	check(4'd3);

	reset();
	dataset = '{5000, 5000, 100, 100, 100, 100, 100, 100, 100, 100};
	for(int i = 0; i < 10; i++) begin
		start_arg(dataset[i], 4'(i));
	end
	check(4'd0);

	reset();
	dataset = '{10, 20, 30, 40, 50, 60, 70, 80, 90, 100};
	for(int i = 0; i < 10; i++) begin
		start_arg(dataset[i], 4'(i));
	end
	check(4'd9);

	$display("passed %d/%d tests", tests_passed, total_tests);

	$finish;
end
endmodule
