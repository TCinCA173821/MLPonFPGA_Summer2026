module argmax_tb;

//tb signals
logic clk = 0, nrst;
logic start;
logic signed [15:0] in,
logic [3:0] in_ptr,
logic [3:0] out

//tests
int tests_passed = 0;
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

initial begin
	$dumpfile("waveform.fst");
	$dumpvars(0, tb_circ_shiftreg);

	nrst = 1'b1;
	
	$timeformat(-9, 2, " ns", 20);
	
	reset();
	@(posedge clk);
	#(10);

	//tests


	$finish;
end
endmodule
