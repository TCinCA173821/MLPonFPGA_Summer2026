module layer_controller (
	input logic clk,
	input logic nrst,
	input logic l_en,
	input logic layer_select,
	input logic mac_done,
	output logic mac_en,
	output logic l_done,
	output logic hlb_wen,
	output logic olb_wen,
	output logic [7:0] mult_iter
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
		IDLE: next_state = (l_en) ? MAC : IDLE;
		MAC: next_state = (mac_done) ? STORE : MAC;
		STORE: next_state = (layer_cnt == total_layers) ? DONE : MAC;
		DONE: next_state = IDLE;
		default: next_state = IDLE;
	endcase
end

always_ff @(posedge clk, negedge nrst) begin
  if(!nrst) begin
	  state <= IDLE;
	  layer_cnt <= 0;
  end else begin
	  state <= next_state;
	  layer_cnt <= next_cnt;
  end
end

always_comb begin
  mac_en = '0;
  l_done = '0;
  next_cnt = layer_cnt;
	total_layers = (layer_select) ? '3 : '2;
  mult_iter = (layer_select) ? 'd15 : 'd195;
	olb_wen = '0;
	hlb_wen = '0;
	
	case(state)
		IDLE: begin
			l_done = '0;
			mac_en = '0;
			next_cnt = '0;
		end
		MAC: begin
      mac_en = '1;
      next_cnt = layer_cnt;
      olb_wen = '0;
		  hlb_wen = '0;
		end
		STORE: begin
      next_cnt = layer_cnt + '1;
      mac_en = '0;
      if(layer_select) begin
	      olb_wen = '1;
	    end else begin
		    hlb_wen = '1;
	    end
    end
		DONE: begin
			l_done = '1;
			mac_en = '0;
			next_cnt = layer_cnt;
			olb_wen = '0;
			hlb_wen = '0;
		end
	endcase
end
