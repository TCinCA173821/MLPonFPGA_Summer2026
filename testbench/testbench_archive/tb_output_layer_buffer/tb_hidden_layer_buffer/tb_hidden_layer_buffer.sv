module tb_hidden_layer_buffer;

//tb signals
logic clk = 0, nrst;
logic wen, ren;
logic increment;
logic [3:0][3:0] in;
logic [3:0][3:0] out;

//tests
int tests_passed = 0;
int i;
logic [3:0][3:0] dataset [0:3];

always #(10) clk++;

hidden_layer_buffer DUT(
	.clk(clk),
	.nrst(nrst),
	.wen(wen),
	.ren(ren),
	.increment(increment),
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

task read();
	ren = '1;
	@(posedge clk);
	#(1);
	$display("read output: %h\n", out);
	ren = '0;
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

task ptr_increment();
	increment = '1;
	@(posedge clk);
	$display("incremented shift register\n");
	#(1)
	increment = '0;
endtask

task test(
	input logic [3:0][3:0] test_data [0:3]
);
	//write data
for(i = 0; i < 4; i++) begin
		write(test_data[i]);
		ptr_increment();
	end
	
	//read data
	for(i = 0; i < 4; i++) begin
		read();
		if(out == test_data[i]) begin
			tests_passed++;
		end
		ptr_increment();
	end

	$display("Tests passed: %0d/4", tests_passed); 
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
  dataset[0] = 16'hAAAA;
  dataset[1] = 16'hBBBB;
  dataset[2] = 16'hCCCC;
  dataset[3] = 16'hDDDD;

  test(dataset);
  $finish;
end
endmodule



