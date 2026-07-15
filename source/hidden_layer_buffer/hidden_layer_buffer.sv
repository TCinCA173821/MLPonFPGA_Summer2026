module hidden_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic ren,
	input logic incr,
	input logic [15:0] in,     // packed 4x4-bit layer (element k = in[4*k +: 4])
	output logic [15:0] out
);

logic [15:0] mem_layers [0:3];
logic [1:0] ptr;

//ptr increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		ptr <= 2'b00;
	end else if (incr) begin
		ptr <= ptr + 1'b1;
	end
end

//write
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		for (int i = 0; i < 4; i++) mem_layers[i] <= '0;
	end else if(wen) begin
		mem_layers[ptr] <= in;
	end
end

//output
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out <= '0;
	end else if (ren) begin
		out <= mem_layers[ptr];
	end
end
	
endmodule
