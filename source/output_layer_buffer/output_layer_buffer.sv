module output_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic ren,
	input logic [3:0][3:0] in,
	output logic [3:0] out
);

logic [3:0] reg [0:11];
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
		reg <= '{default: '0};
	end else if (wen) begin
		reg[wptr] <= in[0];
		reg[wptr+1] <= in[1];
		reg[wptr+2] <= in[2];
		reg[wptr+3] <= in[3];
	end
end


//read increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		rptr <= 4'd0;
	end else if (wen) begin
		rptr <= (wptr + 1) % 10;
	end
end

//output
always_comb begin
	if(ren) begin
		out = reg[rptr];
	end else begin
		out = 4'd0
	end
end
endmodule
