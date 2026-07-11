module tb_output_layer_buffer;

//tb signals
logic clk = 0, nrst;
logic wen, r_inc;
logic [3:0][3:0] in;
logic [3:0] out;

//tests
int tests_passed = 0;
int i;
int count = 0;
logic [3:0][3:0] dataset [0:2];
logic[3:0] temp_out;

always #(10) clk++;

output_layer_buffer DUT(
	.clk(clk),
	.nrst(nrst),
	.wen(wen),
	.r_inc(r_inc),
	.in(in),
	.out(out)
);

task reset();
	nrst = '0;
	repeat(2) @(posedge clk);
	nrst = '1;
	@(posedge clk);
	#(1);
endtask

task read(
	output logic [3:0] test_out
);
	r_inc = '1;
	@(posedge clk);
	test_out = out;
	#(1);
	r_inc = '0;
endtask

task write(
	input logic [3:0][3:0] test_in
);
	wen = '1;
	in = test_in;
	$display("writing %h", in);	
	@(posedge clk);
	#(1);
	wen = '0;
endtask

task test(
	input logic [3:0][3:0] test_data [0:2]
);
	//write data
	for(i = 0; i < 3; i++) begin
		write(test_data[i]);
	end
	
	//read data
	foreach(test_data[i, j]) begin
		read(temp_out);
		$display("expected: %h, actual: %h", test_data[i][j], temp_out);
		if(temp_out == test_data[i][j]) begin
			tests_passed++;
		end

		count++;
		if(count == 10) begin
			break;
		end
	end

	$display("Tests passed: %0d/10", tests_passed); 
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
	dataset[0] = 16'h1234;
	dataset[1] = 16'h5678;
	dataset[2] = 16'h9ABC;

	test(dataset);

	$finish;
end
endmodule


