module argmax (
	input logic clk,
	input logic nrst,
	input logic start,
	input logic [11:0] in,
	input logic [3:0] in_ptr,
	output logic [3:0] out,
);

logic [11:0] out_reg;
logic load_en;

//comparator logic
always_comb begin
	if(start && (in > out_reg)) begin
		comp_out = 2'b01;
		load_en = '1;
	end else begin
		load_en = '0;
	end
end

//register
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out_reg <= 0;
		out <= 0;
	end else if(load_en) begin
		out_reg <= in;
		out <= in_ptr;
	end
end
endmodule
