module hidden_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic ren,
	input logic incr,
	input logic [15:0] in, //4x4 bits
	output logic [15:0] out
);

logic [15:0] mem_layers [3:0];
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
		for (int i = 0; i < 4; i++) mem_layers[i] <= 16'd0;
	end else if(wen) begin
		mem_layers <= {in, mem_layers[3], mem_layers[2], mem_layers[1]};
	end
end

//output
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out <= 1'b0;
	end else if (ren) begin
		out <= mem_layers[ptr];
	end
end
	
endmodule
