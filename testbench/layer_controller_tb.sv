module layer_controller_tb;
  logic clk = 0, n_rst;
  logic Len;
	logic Lsel;
	logic Md;
	logic Men;
	logic Ld;
	logic HLBwen;
	logic OLBwen;
  logic [7:0] Miter;

  layer_controller DUT(.*);
  always #(10) clk++;

	always @(posedge clk) begin
	  if(HLBwen) hlb_cnt++;
      if(OLBwen) olb_cnt++;
	end

  int cycles = 0;
  int hlb_cnt = 0;
  int olb_cnt = 0;
  logic finished = 0;
  
  task reset();
  	n_rst = 1'b0;
  	repeat(2) @(posedge clk);
  	n_rst = 1'b1;
  	@(posedge clk);
  	#(1);
  endtask

  task test(
    input logic test_sel
  );
    Len = 1'b1;
    @(posedge clk);
    #(1);
    Len = 1'b0;
    Lsel = test_sel;

    Md = 1'b1;
    while(!Ld && cycles < 50) begin
      cycles++;
      @(posedge clk);
      #(1);
	  if(Ld) finished = 1'b1;
    end

    if(test_sel) begin //olb
      if(finished && olb_cnt == 2 && Miter == 8'd15) begin
        $display("passed, olb_cnt: %d, miter: %d", olb_cnt, Miter);
      end else begin
        $display("failed, olb_cnt: %d, miter: %d", olb_cnt, Miter);
      end
    end else begin //hlb
      if(finished && hlb_cnt == 3 && Miter == 8'd195) begin
        $display("passed, hlb_cnt: %d, miter: %d", hlb_cnt, Miter);
      end else begin
        $display("passed, hlb_cnt: %d, miter: %d", hlb_cnt, Miter);
      end
    end
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, layer_controller_tb.sv);
  	n_rst = 1'b1;
  	$timeformat(-9, 2, " ns", 20);
  	reset();
  	@(posedge clk);
  	#(10);  

    //tests
    test(0); //hidden layer
    reset();
    test(1); //output layer
    
    $finish;
  end
endmodule
