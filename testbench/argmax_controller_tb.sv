module argmax_controller_tb;
  logic clk = 0, n_rst;
  logic Aen;
	logic Ad;
	logic OLBincr;
	logic ARG_s;

  int arg_s_cnt = 0;
  int OLBincr_cnt = 0;
  int Ad_cnt = 0;
  int cycles = 0;
  
  argmax_controller DUT(.*);
  always #(10) clk++;

  //update signal counts
  always @(posedge clk) begin
    if(ARG_s) arg_s_cnt++;
    if(OLBincr) OLBincr_cnt++;
  end
  
  task reset();
  	n_rst = 1'b0;
  	repeat(2) @(posedge clk);
  	n_rst = 1'b1;
  	@(posedge clk);
  	#(1);
  endtask

  task test();
    Aen = 1'b1;
    @(posedge clk);
    #(1);
    Aen = 1'b0;

    while(Ad == '0 && cycles < 50) begin
      cycles++;
      @(posedge clk);
      #(1);
	  if(Ad == '1) begin
		Ad_cnt++;
	  end
    end

    if(OLBincr_cnt == 10 && arg_s_cnt == 10 && Ad_cnt == 1) begin
      $display("passed, olbincr: %d, arg_s incr: %d, done: %d", OLBincr_cnt, arg_s_cnt, Ad_cnt);
    end else begin
	  $display("failed, olbincr: %d, arg_s incr: %d, done: %d", OLBincr_cnt, arg_s_cnt, Ad_cnt);
	end
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, argmax_controller_tb.sv);
  	n_rst = 1'b1;
  	$timeformat(-9, 2, " ns", 20);
  	reset();
  	@(posedge clk);
  	#(10);  

    //tests
    test();
    
    $finish;
  end
endmodule
