module tob_tb;
  logic hz100, reset;
  logic [20:0] pb;
  logic [7:0] left, right, ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0;
  logic red, green, blue;
  logic [7:0] txdata, rxdata;
  logic txclk, rxclk;
  logic txready, rxready;

  top DUT(.*);
  always #(10) hz100++;
  always #(2) pb[11]++;

  task reset();
    reset = 1'b1;
    repeat(2) @(posedge clk);
    reset = 1'b0;
    @(posedge clk);
    #(1);
  endtask

  task test();
    pb[9] = 1'b1;
    @(posedge clk);
    #(1);
    pb[9] = 1'b0;
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, top_tb.sv);
    n_rst = 1'b1;
    $timeformat(-9, 2, " ns", 20);
    reset();
    @(posedge clk);
    #(10); 


    
    $finish();
  end
endmodule
