module MAC_controller_tb;
  logic clk = 0;
  logic n_rst;
  logic Men;
  logic [7:0] Miter;
  logic Id;
  logic Lsel;
  logic Md;
  logic MAC_s;
  logic MAC_l;
  logic Irq;
  logic Itype;

  always #(10) clk++;
  MAC_controller DUT(.*);

  int Md_count = 0;
  int MAC_s_count = 0;
  int MAC_l_count = 0;
  int Irq_count = 0;
  int Itype_count = 0;
  int cycles = 0;

  always @(posedge clk) begin
    if(Md) Md_count++;
    if(MAC_s) MAC_s_count = 0;
    if(MAC_l) MAC_l_count = 0;
    if(Irq) Irq_count = 0;
	end

  task reset();
  	n_rst = 1'b0;
  	repeat(2) @(posedge clk);
  	n_rst = 1'b1;
  	@(posedge clk);
  	#(1);
  endtask

  task test(
    input logic test_lsel
  );
    Men = 1'b1;
    Lsel = test_lsel
    if(test_lsel) begin
      Miter = 8'd195;
    end else begin
      Miter = 8'd15;
    end
    
    @(posedge clk);
    #(1);
    Men = 1'b0;
    
    //simulate data recieved
    Id = 1'b1;
    
    while(!Ld && cycles < 300) begin
      cycles++;
      @(posedge clk);
      #(1);
      if(Md) Md_count = 1'b1;
    end

    if(test_lsel) begin
      if(Md_count && MAC_s_count == 196 && MAC_l_count == 196 && Irq_count == 197 && Itype_count == 0) begin
        $display("passed, Md_count: %d, MAC_s count: %d, MAC_l count: %d, Irq count: %d, Itype count: %d", Md_count, MAC_s_count, MAC_l_count, Irq_count, Itype_count);
      end else begin
        $display("failed, Md_count: %d, MAC_s count: %d, MAC_l count: %d, Irq count: %d, Itype count: %d", Md_count, MAC_s_count, MAC_l_count, Irq_count, Itype_count);
      end
    end else begin
      if(Md_count && MAC_s_count == 196 && MAC_l_count == 196 && Irq_count == 197 && Itype_count == 0) begin
        $display("passed, Md_count: %d, MAC_s count: %d, MAC_l count: %d, Irq count: %d, Itype count: %d", Md_count, MAC_s_count, MAC_l_count, Irq_count, Itype_count);
      end else begin
        $display("failed, Md_count: %d, MAC_s count: %d, MAC_l count: %d, Irq count: %d, Itype count: %d", Md_count, MAC_s_count, MAC_l_count, Irq_count, Itype_count);
      end
    end
    
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, MAC_controller_tb.sv);
  	n_rst = 1'b1;
  	$timeformat(-9, 2, " ns", 20);
  	reset();
  	@(posedge clk);
  	#(10);  

    //test hidden layer
    test(0);
    reset();
    //test output layer
    test(1);
    
    $finish;
  end
endmodule
