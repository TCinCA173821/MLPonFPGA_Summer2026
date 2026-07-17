module layer_controller (
	input logic clk,
	input logic n_rst,
	input logic Len,
	input logic Lsel,
	input logic Md,
	output logic Men,
	output logic Ld,
	output logic HLBwen,
	output logic OLBwen,
	output logic [7:0] Miter
);

	logic [1:0] layer_cnt, next_cnt, total_layers;

	//states
	typedef enum logic [1:0] {
	IDLE,
	MAC,
	STORE,
	DONE
	} state_t;
	state_t state, next_state;

	always_comb begin
		case(state)
			IDLE: next_state = (Len) ? MAC : IDLE;
			MAC: next_state = (Md) ? STORE : MAC;
			STORE: next_state = (next_cnt == total_layers) ? DONE : MAC;
			DONE: next_state = IDLE;
			default: next_state = IDLE;
		endcase
	end

	always_ff @(posedge clk, negedge n_rst) begin
	if(!n_rst) begin
		state <= IDLE;
		layer_cnt <= 1'b0;
	end else begin
		state <= next_state;
		layer_cnt <= next_cnt;
	end
	end

	always_comb begin
	Men = 1'b0;
	Ld = 1'b0;
	next_cnt = layer_cnt;
	total_layers = (Lsel) ? 2'd3 : 2'd4;
	Miter = (Lsel) ? 8'd15 : 8'd195;
	OLBwen = 1'b0;
	HLBwen = 1'b0;
		
		case(state)
			IDLE: next_cnt = 1'b0;
			MAC: Men = 1'b1;
			STORE: begin
				next_cnt = layer_cnt + 2'd1;
				if(Lsel) OLBwen = 1'b1;
				else HLBwen = 1'b1;
			end
			DONE: Ld = 1'b1;
		endcase
	end
endmodule
