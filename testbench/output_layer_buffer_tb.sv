module tb_output_layer_buffer;

//tb signals
logic clk = 0, nrst;
logic wen, r_inc;
logic [63:0] in;
logic [15:0] out_data;
logic [3:0] rptr;

//tests
int tests_passed = 0;
logic [15:0] dataset [0:2];

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
  input logic [3:0] expected_ptr
);
	r_inc = '1;
	@(posedge clk);
  $display("reading: out_data: %h, rptr: %h", out_data, rptr);	
  if(out_data == expected_data && rptr == expected_ptr) begin
    tests_passed++;
  end
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
  input logic [15:0] test_data [0:2]
);
	//write data
  for(int i = 0; i < 3; i++) begin
		write(test_data[i]);
	end
	
	//read data
  for(int i = 0; i < 10; i++) begin
    read(test_data[i], i);
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


