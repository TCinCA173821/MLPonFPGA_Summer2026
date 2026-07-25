module hidden_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic ren,
	input logic incr,
	input logic [15:0] in, //4x4 bits
	output logic [3:0] out
);

logic [63:0] mem_layers;
logic [3:0] ptr;


//ptr increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		ptr <= 4'b00;
	end else if (incr) begin
		ptr <= ptr + 4'd1;
	end
end

//write
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		for (int i = 0; i < 4; i++) mem_layers[16*i +:16] <= 16'd0;
	end else if(wen) begin
		mem_layers <= {mem_layers[47:0], in[3:0], in[7:4], in[11:8], in[15:12]};
	end
end

//output
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out <= 4'b0;
	end else if (ren) begin
		out <= mem_layers[63 - (ptr[3:0]*4) -: 4];
	end
end
	
endmodule
