module output_layer_buffer_tb;

//tb signals
logic clk = 0, nrst;
logic wen, r_inc;
logic [63:0] in;
logic [15:0] out_data;
logic [3:0] rptr;

//tests
int tests_passed = 0;
logic [63:0] dataset [0:2];

always #(10) clk++;

output_layer_buffer DUT(
	.clk(clk),
	.nrst(nrst),
	.wen(wen),
	.r_inc(r_inc),
	.in(in),
	.out_data(out_data),
	.rptr(rptr)
);

task reset();
	nrst = '0;
	repeat(2) @(posedge clk);
	nrst = '1;
	@(posedge clk);
	#(1);
endtask

task read(
  input logic [15:0] expected_data,
);
	r_inc = '1;
	@(posedge clk);
  $display("reading: out_data: %h, rptr: %h, expected: %h", out_data, rptr, expected_data);	
  if(out_data == expected_data) begin
    tests_passed++;
  end
	#(1);
	r_inc = '0;
endtask

task write(
	input logic [63:0] test_in
);
	wen = '1;
	in = test_in;
	$display("writing %h", in);	
	@(posedge clk);
	#(1);
	wen = '0;
endtask

task test(
  input logic [63:0] test_data [0:2]
);
	//write data
  for(int i = 0; i < 3; i++) begin
		write(test_data[i]);
	end
	
	//read data
	for(int i = 0; i < 3; i++) begin
		for(int j = 0; j < 4; j++) begin
			if(i == 2 && j == 2) begin
				break;
			end
			read(test_data[i][63 - (j * 16) -: 16]);
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
	dataset[0] = 64'h1234123789182732;
	dataset[1] = 64'h5678abc21bca1392;
	dataset[2] = 64'h9ABC9a87cb9a7cb7;

	test(dataset);

	$finish;
end
endmodule
