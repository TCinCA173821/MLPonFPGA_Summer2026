module tb_MACBlock;

//tb signals
logic signed [3:0] input1_signed;
logic [3:0] input2_unsigned;
logic start, load_bias;
logic clk, n_rst;
logic [3:0] MACout_RELU;
logic signed [15:0] MACout_REG;
logic data_valid;

//test signals
logic [7:0] test_bias;
logic signed [3:0] test_in1[0:3];
logic [3:0] test_in2[0:3];
logic [3:0] test_expected;
int i;
int tests_passed = 0;

always #(10) clk++;

MACblock DUT(
	.input1_signed(input1_signed),
	.input2_unsigned(input2_unsigned),
	.start(start),
	.load_bias(load_bias),
	.clk(clk),
	.n_rst(n_rst),
	.MACout_RELU(MACout_RELU),
	.MACout_REG(MACout_REG),
	.data_valid(data_valid)
);

task reset();
	n_rst = '0;
	repeat(2) @(posedge clk);
	n_rst = '1;
	@(posedge clk);
	#(1);
endtask

task bias(
	input logic signed [7:0] bias_input
);
	start = '1;
	load_bias = '1;
	
	input1_signed = bias_input[7:4];
	input2_unsigned = bias_input[3:0];

	$display("load bias: %b, %b", input1_signed, input2_unsigned);
	
	@(posedge clk);
	start = '0;
	load_bias = '1;
	#(1);
endtask

task multiply(
	input logic signed [3:0] in1,
	input logic [3:0] in2
);
	start = '1;
	input1_signed = in1;
	input2_unsigned = in2;
	
	$display("multipling: %d (%b), %d (%b) = %d", in1, in1, in2, in2, (signed'({{12{input1_signed[3]}}, input1_signed}) * signed'({{12{1'b0}}, input2_unsigned})));

	@(posedge clk);
	start = '0;
	#(1);
endtask

task run_test(
	input logic signed [7:0] in_bias,
	input logic signed [3:0] in1 [0:3],
	input logic [3:0] in2 [0:3],
	input logic [3:0] expected
);
	bias(in_bias);

	for(i = 0; i < 4; i++) begin
		while(!data_valid) begin
			@(posedge clk);
			#(1);
		end
		$display("register output: %d, relu: %d", MACout_REG, MACout_RELU);
		multiply(in1[i], in2[i]);
	end	

	while(!data_valid) begin
		@(posedge clk);
		#(1);
	end

	$display("register output: %d, relu: %d, expected: %d", MACout_REG, MACout_RELU, expected);
	if(MACout_RELU == expected) begin
		tests_passed++;
	end
endtask

initial begin
	$dumpfile("waveform.fst");
	$dumpvars(0, tb_argmax);
	n_rst = 1'b1;
	$timeformat(-9, 2, " ns", 20);
	reset();
	@(posedge clk);

	//tests
	test_bias = -8'sd100;
	test_in1[0] = 4'sd4;
	test_in1[1] = -4'sd5;
	test_in1[2] = 4'sd7;
	test_in1[3] = 4'sd6;

	test_in2[0] = 4'd9;
	test_in2[1] = 4'd14;
	test_in2[2] = 4'd11;
	test_in2[3] = 4'd2;

	test_expected = 4'b0000;

	run_test(test_bias, test_in1, test_in2, test_expected);

	$finish;
end

endmodule
