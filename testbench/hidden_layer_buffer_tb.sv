module hidden_layer_buffer_tb;

//tb signals
logic clk = 1'b0, nrst;
logic wen, incr;
logic [15:0] in;
logic [15:0] out;

//tests
int tests_passed = 0;
logic [15:0] test_data [0:3];

always #(10) clk++;

hidden_layer_buffer DUT(
	.clk(clk),
	.nrst(nrst),
	.wen(wen),
	.r_inc(r_inc),
	.in(in),
	.out(out)
);

task reset();
	nrst = 1'b0;
	repeat(2) @(posedge clk);
	nrst = 1'b1;
	@(posedge clk);
	#(1);
endtask

task read();
	r_inc = 1'b1;
	@(posedge clk);
	#(1);
	r_inc = 1'b0;
endtask

task write(
	input logic [3:0][3:0] test_in
);
	wen = 1'b1;
	in = test_in;
	$display("writing %h", in);	
	@(posedge clk);
	#(1);
	wen = 1'b0;
endtask

task test(
  input logic [15:0] data [0:3]
);
	//write data
  for(int i = 0; i < 4; i++) begin
    write(data[i]);
	end
	
	//read data
  for(int i = 0; i < 4; i++) begin
    if(out == data[i]) begin
			$display("read output: %h\n", out);
			tests_passed++;
		end
		read();
	end

	$display("Tests passed: %0d/4", tests_passed); 
endtask

initial begin
	$dumpfile("waveform.fst");
  $dumpvars(0, hidden_layer_buffer_tb.sv);
	nrst = 1'b1;
	$timeformat(-9, 2, " ns", 20);
	
	reset();
	@(posedge clk);
	#(10);

	//tests
	test_data[0] = 16'hAAAA;
	test_data[1] = 16'hBBBB;
	test_data[2] = 16'hCCCC;
	test_data[3] = 16'hDDDD;

	test(test_data);

	$finish;
end
endmodule

