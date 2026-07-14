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

//register
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out_reg <= 0;
		out <= 0;
	end else if(start && (in > out_reg)) begin
		out_reg <= in;
		out <= in_ptr;
	end
end
endmodule
