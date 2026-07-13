module argmax_controller (
	input logic clk,
	input logic nrst,
	input logic arg_en,
	input logic arg_dv,
	output logic arg_done,
	output logic buffer_inc,
	output logic arg_start
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
		IDLE: next_state = arg_en ? RUN : IDLE;
		RUN: next_state = INCR;
		INCR: next_state = (node == 'd9) ? DONE : RUN;
		DONE: next_state = IDLE;
		default: next_state = IDLE;
		end
	endcase
end

//state and node num changes
always_ff @(posedge clk, negedge nrst) begin
	if(nrst) begin
		state <= IDLE;
		node <= '0;
	end else begin
		state <= next_state;
		node <= next_node;
	end
end

//signal updates
always_comb begin
	arg_done = '0;
	buffer_inc = '0;
	arg_start = '0;
	next_node <= node;

	case(state)
		IDLE: begin
            arg_done = '0;
            buffer_inc = '0;
            arg_start = '0;
			next_node <= '0;
        end
        RUN: begin
			arg_start = '1;
			buffer_inc = '0;
			arg_done = '0;
			next_node = node;
		end
		INCR: begin
			buffer_inc = '1;
			arg_start = '0;
			arg_done = '0
			next_node = node + 1;
		end
		DONE: begin
			arg_done = '1;
			buffer_inc = '0;
			arg_start = '0;
			next_node = '0;
		end
	endcase
end
endmodule
