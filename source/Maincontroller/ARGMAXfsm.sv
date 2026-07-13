module argmax_controller (
	input logic clk,
	input logic nrst,
	input logic arg_en,
	input logic arg_dv,
	input logic [3:0] node,
	output logic arg_done,
	output logic buffer_inc;
	output logic arg_start
);

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
		node <= '0;
		state <= IDLE;
	end else begin
		node <= next_node;
		state <= next_state;
	end
end

//signal updates
always_comb begin
	arg_done = '0;
	buffer_inc = '0;
	arg_start = '0;

	case(state)
		IDLE: begin
            arg_done = '0;
            buffer_inc = '0;
            arg_start = '0;
        end
        RUN: begin
			arg_start = '1;
			buffer_inc = '0;
			arg_done = '0;
		end
		INCR: begin
			buffer_inc = '1;
			arg_start = '0;
			arg_done = '0
		end
		DONE: begin
			arg_done = '1;
			buffer_inc = '0;
			arg_start = '0;
		end
	endcase
end
endmodule
