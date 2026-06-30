module multiplier_mixed4x4 (
    input logic signed [3:0] input1_signed,
    input logic [3:0] input2_unsigned,
    output logic signed [7:0] output_signed
);
    assign output_signed = input1_signed * signed'({1'b0,input2_unsigned});

endmodule

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
        IDLE = 2'd0,
        RUNNING = 2'd1,
        DONE = 2'd2,
        BIASLOAD = 2'd3
    } state_t;

    state_t curstate, nxtstate;

    logic signed [ACCWIDTH - 1:0] accumulate_val, accvalnxt;
    logic signed [7:0] multiplier_out;
    logic regwriteen;

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
                end else if (start)begin
                    nxtstate = RUNNING;
                end else begin
                    nxtstate = IDLE;
                end
            end
            RUNNING: nxtstate = DONE;
            DONE: nxtstate = IDLE;
            BIASLOAD: nxtstate = IDLE;
        endcase
    end

    always_comb begin : moduleoutputs
        regwriteen = 1'b0;
        data_valid = 1'b0;
        case (curstate)
            IDLE: data_valid = 1'b1;
            RUNNING: begin 
                data_valid = 1'b0;
                regwriteen = 1'b1;
            end
            DONE: data_valid = 1'b1;
            BIASLOAD: data_valid = 1'b0;
        endcase
    end

    always_ff @ (posedge clk or negedge n_rst) begin : accumulateupdate
        if(!n_rst) accumulate_val <= 16'd0;
        else accumulate_val <= accvalnxt;
    end

    always_comb begin : accumulationlogic

        if(curstate == BIASLOAD) accvalnxt = {input1_signed,input2_unsigned};
        else if (regwriteen) accvalnxt = accumulate_val;
        accvalnxt = accumulate_val + multiplier_out;
    end

    multiplier_mixed4x4 multiplier(.input1_signed(input1_signed), .input2_unsigned(input2_unsigned),.output_signed(multiplier_out));
    assign MACout = accumulate_val;

endmodule