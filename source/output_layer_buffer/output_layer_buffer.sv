module output_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic r_inc,
	input logic [3:0][3:0] in,
	output logic [3:0] out
);

logic [3:0] output_reg [0:11];
logic [3:0] wptr;
logic [3:0] rptr;

//write increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		wptr <= 4'd0;
	end else if (wen) begin
		if(wptr == 4'd8) begin
			wptr <= 4'd0;
		end else begin
			wptr <= (wptr + 4'd4);
		end
	end
end

//input
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		output_reg <= '{default: '0};
	end else if (wen) begin
		output_reg[wptr] <= in[3];
		output_reg[wptr+4'd1] <= in[2];
		output_reg[wptr+4'd2]<= in[1];
		output_reg[wptr+4'd3] <= in[0];
	end
end

//read increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		rptr <= 4'd0;
	end else if (r_inc) begin
		if(rptr == 4'd9) begin
			rptr <= 4'd0;
		end else begin
			rptr <= (rptr + 4'd1);
		end
	end
end

//output
assign out = output_reg[rptr];
