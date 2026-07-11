module hidden_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic r_inc,
	input logic [3:0][3:0] in,
	output logic [3:0][3:0] out
);

logic [3:0][3:0] mem_layers [0:3];
logic [1:0] ptr;

//ptr increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		ptr <= 2'b00;
	end else if (wen || r_inc) begin
ptr <= ptr + 1'b1;
	end
end

//write
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
	mem_layers <= '{default: '0};
end else if(wen) begin
		mem_layers[ptr] <= in;
	end
end

//output
assign out = mem_layers[ptr];

endmodule
