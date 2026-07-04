module circular_shift_register (
	input logic clk,
	input logic nrst,
	input logic increment, 
	input logic wen,
	input logic ren,
	input logic [3:0][3:0] in,
	output logic [3:0][3:0] out
);

logic [3:0][3:0] mem_layers [0:3];
logic [1:0] ptr;

//ptr increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		ptr <= 2’b00;
	end else if (increment) begin
		ptr <= ptr + 1’b1;
	end
end

//read
always_comb begin
	if(ren) begin
		out = mem_layers[ptr];
	end else begin
		out = 0;
	end
end

//write
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
	mem_layers <= '0;
end else if(wen) begin
		mem_layers[ptr] <= in;
	end
end

endmodule


