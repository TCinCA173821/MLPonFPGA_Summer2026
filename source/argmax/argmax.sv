module argmax (
	input logic clk,
	input logic nrst,
	input logic start,
	input logic [11:0] in,
	input logic [3:0] in_ptr,
	output logic [3:0] out,
);

logic [3:0] count;
logic [11:0] out_reg;
logic [1:0] comp_out; 
logic reg_reset;
logic load_en;

//fsm
typedef enum logic[1:0] {
	IDLE,
	ACTIVE,
	DONE
} state_t;

//state logic
state_t state, next_state;
always_comb begin
	next_state = state;
	casez(state)
		IDLE: begin
			if(start) begin
				next_state = ACTIVE;
			end
		end
		ACTIVE: begin
			if(in_ptr == 9) begin
				next_state = DONE;
			end
		end
		DONE: begin
			next_state = IDLE;
		end
		default: next_state = IDLE;
	endcase
end

//FSM logic
always_comb begin
	data_valid = 0;
	nxt_out = 0;
	reg_reset = 0;
	load_en = 0;

	casez(state)
		IDLE: begin
			data_valid = 1;
			nxt_out = 0;
			reg_reset = 1;
			load_en = 0;
		end
		ACTIVE: begin
			data_valid = 0;
			nxt_out = 1;
			reg_reset = 0;
			
			if(comp_out == 2'b01) begin
				load_en = 1;
			end
		end
		DONE: begin
			data_valid = 1;
			nxt_out = 0;
			reg_reset = 0;
			load_en = 0;
		end
		default: begin
			data_valid = 0;
			nxt_out = 0;
			reg_reset = 0;
			load_en = 0;
		end
	endcase
end

//state transitions
always_ff @(posedge clk or negedge nrst) begin
	if (!nrst) begin
		state <= IDLE;
	end else begin
		state <= next_state;
	end
end

//comparator logic
always_comb begin
	if(in > out_reg) begin
		comp_out = 2'b01;
	end else begin
		comp_out = 2'b10;
	end
end

//register
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst || reg_reset) begin
		out_reg <= 0;
		out <= 0;
	end else if(load_en) begin
		out_reg <= in;
		out <= in_ptr;
	end
end

endmodule
