module argmax_controller (
	input logic clk,
	input logic n_rst,
	input logic Aen,
	output logic Ad,
	output logic OLBincr,
	output logic ARG_s
);

logic [3:0] node, next_node;
	
//states
typedef enum logic [1:0] {
	IDLE,
	RUN,
	INCR,
	DONE
} state_t;
state_t state, next_state;

//state change logic
always_comb begin
	case(state)
		IDLE: next_state = Aen ? RUN : IDLE;
		RUN: next_state = INCR;
		INCR: next_state = (node == 'd9) ? DONE : RUN;
		DONE: next_state = IDLE;
		default: next_state = IDLE;
	endcase
end

//state and node num changes
always_ff @(posedge clk, negedge n_rst) begin
	if(!n_rst) begin
		state <= IDLE;
		node <= '0;
	end else begin
		state <= next_state;
		node <= next_node;
	end
end

//signal updates
always_comb begin
	Ad = '0;
	OLBincr = '0;
	ARG_s = '0;
	next_node = node;

	case(state)
		IDLE: next_node = '0;
        RUN: ARG_s = '1;
		INCR: begin
			OLBincr = '1;
			next_node = node + 1;
		end
		DONE: Ad = '1;
	endcase
end
endmodule
