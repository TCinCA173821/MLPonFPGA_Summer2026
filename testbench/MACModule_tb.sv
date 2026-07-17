module MACModule_tb;
  logic clk = 0, n_rst;
  logic [7:0] MAC_in;
  logic MAC_s;
  logic MAC_l;
  logic signed [15:0] MAC_out;
  logic [3:0] MAC_outrelu;

  //test variables
  logic [15:0] test_reg;
    
  MACModule DUT(.*);

  always #(10) clk++;

  task reset();
  	n_rst = 1'b0;
  	repeat(2) @(posedge clk);
  	n_rst = 1'b1;
  	@(posedge clk);
  	#(1);
  endtask

  task load_bias(
    input logic [7:0] test_bias
  );
    MAC_l = 1'b1;
    MAC_in = test_bias;
  	@(posedge clk);
    #(1);
  	MAC_l = 1'b0;
    test_reg = signed'(test_bias)
  endtask

  task accumulate(
    input logic [3:0] a, b
  );
    MAC_s = 1'b1;
    MAC_in = {a, b};
    @(posedge clk);
    #(1);
  	MAC_l = 1'b0;
    test_reg = test_reg + (signed'(a) * signed'({1'b0, u}));
  endtask

  task check_out();
    //test relu calculations
    logic [3:0] test_relu_out;
    if(test_reg[15]) test_relu_out = '0;
    else if (|test_reg[14:4]) test_relu_out = 4'b1111;
    else test_relu_out = v[3:0];

    if(MAC_out == test_reg && test_relu_out == MAC_outrelu) begin
      $display("passed, relu out: %h, expected: %h, mac out: %h, expected: %h", MAC_outrelu, test_relu_out, MAC_out, test_reg);
    end else begin
      $display("failed, relu out: %h, expected: %h, mac out: %h, expected: %h", MAC_outrelu, test_relu_out, MAC_out, test_reg));
    end
  endtask

  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, hidden_layer_buffer_tb.sv);
  	n_rst = 1'b1;
  	$timeformat(-9, 2, " ns", 20);
  	
  	reset();
  	@(posedge clk);
  	#(10);

    //tests
    load_bias(-8'sd100);
    check_out();
    accumulate( 4'sd4, 4'd9);
    check_out();
    accumulate(-4'sd5, 4'd14);
    check_out();
    accumulate( 4'sd7, 4'd11);
    check_out();
    accumulate( 4'sd2, 4'd2);
    check_out();

    $finish;
  end
endmodule
