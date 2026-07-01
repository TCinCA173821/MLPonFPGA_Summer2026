module MACblock #(
    parameter int ACCWIDTH = 16
)(
    input logic signed [3:0] input1_signed,
    input logic [3:0] input2_unsigned,
    input logic start,
    input logic load_bias,
    input logic clk,
    input logic n_rst,
    output logic signed [ACCWIDTH - 1:0] MACout,
    output logic data_valid
);

    typedef enum logic [1:0] {
        IDLE     = 2'd0,
        RUNNING  = 2'd1,
        DONE     = 2'd2,
        BIASLOAD = 2'd3
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
                if(load_bias) begin
                    nxtstate = BIASLOAD;
                end else if (start) begin
                    nxtstate = RUNNING;
                end else begin
                    nxtstate = IDLE;
                end
            end
            RUNNING:  nxtstate = DONE;
            DONE:     nxtstate = IDLE;
            BIASLOAD: nxtstate = IDLE;
            default:  nxtstate = IDLE;
        endcase
    end

    always_comb begin : moduleoutputs
        data_valid = 1'b0;
        case (curstate)
            IDLE:     data_valid = 1'b1;
            RUNNING:  data_valid = 1'b0;
            DONE:     data_valid = 1'b1;
            BIASLOAD: data_valid = 1'b0;
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
            BIASLOAD: accvalnxt = $signed({input1_signed, input2_unsigned});
            RUNNING: accvalnxt = accumulate_val + (input1_signed * signed'({1'b0, input2_unsigned}));
            default: accvalnxt = accumulate_val;
        endcase
    end
    assign MACout = accumulate_val;

endmodule
