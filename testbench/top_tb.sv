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
  always #(40) pb[11]++;

  int cycles = 0;
  int i = 0;
  logic finished;
  logic[7:0] test_biases [0:25]

  task reset();
    reset = 1'b1;
    repeat(2) @(posedge clk);
    reset = 1'b0;
    @(posedge clk);
    #(1);
  endtask

  task send_data(
    input logic [7:0] test_input,
    input logic [3:0] expected
  );
    pb[10] = 1'b1;
    pb[19:12] = test_input;
    @(posedge SCLK);
    #(1);
    pb[10] = 1'b0;
  endtask
  
  task test(
    input logic[7:0] test_biases [0:25]
  );
    pb[9] = 1'b1;
    @(posedge clk);
    #(1);
    pb[9] = 1'b0;

    while(!finished && cycles < 100000) begin
      if(left[1]) begin
        if(((i % 196 == 0) && i < 784) || ((i - 784) % 16 == 0)) begin
          send_data(test_data[i]);
        end 
        i++;
      end
      
      if(left[0]) finished = 1'b1;
    end

    if(finished && left[5:2] == out) begin
      $display("passed: expected: %d, out: %d", expected, out);
    end else begin
      $display("failed: expected: %d, out: %d", expected, out);
    end
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, top_tb.sv);
    n_rst = 1'b1;
    $timeformat(-9, 2, " ns", 20);
    reset();
    @(posedge clk);
    #(10); 

    for(int i = 0; i < 26; i++) begin
      test_biases[i] = 1'd1;
    end
    test_biases[25] = 1'd100;

    test(test_biases, 3'd9);
    
    $finish();
  end
endmodule
