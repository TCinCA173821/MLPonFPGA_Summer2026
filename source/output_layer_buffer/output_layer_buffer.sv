module output_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic r_inc,
	input logic [63:0] in,     // packed 4x16-bit (element k = in[16*k +: 16])
	output logic [15:0] out_data,
	output logic [3:0] rptr
);

logic [15:0] output_reg [0:11];
logic [3:0] wptr;

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
		for (int i = 0; i < 12; i++) output_reg[i] <= 16'b0;
	end else if (wen) begin
		output_reg[wptr] <= in[16*3 +: 16];
		output_reg[wptr+4'd1] <= in[16*2 +: 16];
		output_reg[wptr+4'd2] <= in[16*1 +: 16];
		output_reg[wptr+4'd3] <= in[16*0 +: 16];
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
assign out_data = output_reg[rptr];
endmodule
