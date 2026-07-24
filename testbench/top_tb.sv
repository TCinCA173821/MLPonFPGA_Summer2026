module top_tb;
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
  int req_cnt = 0;
  logic finished;
  logic[7:0] test_biases [0:25];
  int bias_ptr = 0;
  logic nxt_d;

  always @(posedge hz100) nxt_d <= left[1];

  task rst();
    reset = 1'b1;
    repeat(2) @(posedge hz100);
    reset = 1'b0;
    @(posedge hz100);
    #(1);
  endtask

  task send_data(
    input logic [31:0] test_input,
	input logic isbias
  );
    pb[10] = 1'b1;
	for(int i = 0; i < 4; i++) begin	
	    pb[19:12] = test_input[8*i +: 8];
		if(isbias) $display("bias sent: %d", pb[19:12]);
    	@(posedge pb[11]);
		#(1);
	end
    pb[10] = 1'b0;
  endtask
  
  task test(
    input logic[7:0] test_data [0:25],
	input logic [3:0] expected
  );
    pb[9] = 1'b1;
    @(posedge hz100);
    #(1);
    pb[9] = 1'b0;

    while(!finished && cycles < 200000) begin
      if(left[1] && !nxt_d) begin
        if(req_cnt == 0   || req_cnt == 197 || req_cnt == 394 || req_cnt == 591 ||
          req_cnt == 788 || req_cnt == 805 || req_cnt == 822) begin
          send_data({test_data[bias_ptr+3], test_data[bias_ptr+2], test_data[bias_ptr+1], test_data[bias_ptr+0]}, 1'b1);
		  if(bias_ptr < 25) bias_ptr+=4;
		  $display("bias sent: bias ptr: %d, req cnt: %d", bias_ptr, req_cnt);
		  req_cnt++;
        end else begin
		  send_data(32'b0, 1'b0);
		  req_cnt++;
		end
      end
      
      if(left[0]) finished = 1'b1;
	  @(posedge hz100);
	  #(1);
	  cycles++;
    end

    if(finished && (left[5:2] == expected)) begin
      $display("passed: expected: %d, out: %d, reqcnt: %d", expected, left[5:2], req_cnt);
    end else begin
      $display("failed: expected: %d, out: %d, reqcnt: %d", expected, left[5:2], req_cnt);
    end
  endtask
  
  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, top_tb.sv);
    reset = 1'b0;
    $timeformat(-9, 2, " ns", 20);
    rst();
    @(posedge hz100);
    #(10); 

    for(int i = 0; i < 26; i++) begin
      test_biases[i] = 8'd1 + 8'(i);
    end
    test_biases[23] = 8'd100;

    test(test_biases, 4'd7);
    
    $finish();
  end
endmodule
