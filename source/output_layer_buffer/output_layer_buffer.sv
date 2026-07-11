module output_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic ren,
	input logic [3:0][15:0] in,
	output logic [15:0] out
);

logic [3:0] output_reg [0:15];
logic [3:0] wptr;
logic [3:0] rptr;

//write increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		wptr <= 4'd0;
	end else if (wen) begin
		wptr <= (wptr + 4) % 12;
	end
end

//input
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		output_reg <= '{default: '0};
	end else if (wen) begin
		output_reg[wptr] <= in[3];
		output_reg[wptr+1] <= in[2];
		output_reg[wptr+2] <= in[1];
		output_reg[wptr+3] <= in[0];
	end
end

//read increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		rptr <= 4'd0;
	end else if (ren) begin
		rptr <= (rptr + 1) % 10;
	end
end

//output
always_comb begin
	if(ren) begin
		out = output_reg[rptr];
	end else begin
		out = 4'd0;
	end
end
endmodule
