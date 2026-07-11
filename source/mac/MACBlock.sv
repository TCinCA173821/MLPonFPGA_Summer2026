module MACblock #(
    parameter int ACCWIDTH = 16
)(
    input logic signed [3:0] input1_signed,
    input logic [3:0] input2_unsigned,
    input logic start,
    input logic clk,
    input logic n_rst,
	input logic load_bias,
    output logic [3:0] MACout_RELU,
    output logic signed [ACCWIDTH - 1:0] MACout_REG,
    output logic data_valid
);

    typedef enum logic [1:0] {
        IDLE     = 2'd0,
        RUNNING  = 2'd1,
        BIASLOAD = 2'd2
    } state_t;

    state_t curstate, nxtstate;

    logic signed [ACCWIDTH - 1:0] accumulate_val, accvalnxt;

    always_ff @ (posedge clk or negedge n_rst) begin : statereg
        if(!n_rst) begin
            curstate <= IDLE;
        end else begin
            curstate <= nxtstate;
        end
    end

    always_comb begin : nxtstatelogic
        case (curstate) 
            IDLE: begin
                if(load_bias && start) begin
                    nxtstate = BIASLOAD;
                end else if (start) begin
                    nxtstate = RUNNING;
                end else begin
                    nxtstate = IDLE;
                end
            end
            RUNNING:  nxtstate = IDLE;
            BIASLOAD: nxtstate = IDLE;
            default:  nxtstate = IDLE;
        endcase
    end

    always_comb begin : moduleoutputs
        data_valid = 1'b0;
        case (curstate)
            IDLE:     data_valid = 1'b1;
            RUNNING:  data_valid = 1'b0;
            BIASLOAD: data_valid = 1'b0;
            default: data_valid = '0;
        endcase
    end

    always_ff @ (posedge clk or negedge n_rst) begin : accumulateupdate
        if(!n_rst) begin
            accumulate_val <= '0;
        end else begin
            accumulate_val <= accvalnxt;
        end
    end

    always_comb begin : accumulationlogic
		case (curstate)
            BIASLOAD: accvalnxt = $signed({{8{input1_signed[3]}}, input1_signed, input2_unsigned});
            RUNNING: accvalnxt = signed'(accumulate_val)+(signed'({{12{input1_signed[3]}}, input1_signed}) * signed'({{12{1'b0}}, input2_unsigned}));
            default: accvalnxt = accumulate_val;
        endcase
    end
    assign MACout_REG = accumulate_val;

    relu_truncate r1(.relu_en(1'b1),.relu_in(accumulate_val),.relu_out(MACout_RELU));
    

endmodule

module relu_truncate (
    input  logic        relu_en,
    input  logic signed [15:0] relu_in,
    output logic        [3:0]  relu_out
);

    always_comb begin
        relu_out = 4'b0000;

        if (relu_en) begin
            if (relu_in[15] == 1'b1)
                relu_out = 4'b0000;
            else if (|relu_in[14:3])
                relu_out = 4'b0111;
            else
                relu_out = relu_in[3:0];
        end
    end

endmodule
