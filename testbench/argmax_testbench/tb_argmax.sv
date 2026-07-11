module tb_argmax;

//tb signals
logic clk = 0, nrst;
logic start;
logic [11:0] in;
logic [3:0] out;
logic data_valid;
logic nxt_out;

logic [11:0] test_data [0:9];
logic [3:0] test_expected;
int tests_passed = 0;
int i;

always #(10) clk++;

argmax DUT(
	.clk(clk),
	.nrst(nrst),
	.start(start),
	.in(in),
	.out(out),
	.data_valid(data_valid),
	.nxt_out(nxt_out)
);

task reset();
	nrst = '0;
	repeat(2) @(posedge clk);
	nrst = '1;
	@(posedge clk);
	#(1);
endtask

task test(
	input logic [11:0] data [0:9],
	input logic [3:0] expected
);
	start = '1;
	@(posedge clk);
	start = '0;

	for(i = 0; i < 10; i++) begin
		in = data[i];
		$display("inputting: %h", data[i]);
		@(posedge clk);
	end	

	$display("expected: %h, got %h\n", expected, out);
	if(out == expected) begin
		tests_passed++;
	end
endtask

initial begin
	$dumpfile("waveform.fst");
	$dumpvars(0, tb_argmax);
	nrst = 1'b1;
	$timeformat(-9, 2, " ns", 20);
	reset();
	@(posedge clk);

	//tests
	test_data[0] = 12'd123;
	test_data[1] = 12'd456;
	test_data[2] = 12'd223;
	test_data[3] = 12'd4050;
	test_data[4] = 12'd932;
	test_data[5] = 12'd123;
	test_data[6] = 12'd764;
	test_data[7] = 12'd384;
	test_data[8] = 12'd523;
	test_data[9] = 12'd523;
	test_expected = 4;

	test(test_data, test_expected);

	$finish;
end

endmodule
