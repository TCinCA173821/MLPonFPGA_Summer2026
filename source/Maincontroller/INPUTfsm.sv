module INPUTfsm(
    input logic clk,
    input logic n_rst,
    input logic input_sel,
    input logic input_rq,
    input logic [31:0] SPI_out,
    input logic SPI_dv,
    input logic [3:0][3:0] HLBrdata,
    output logic SPI_rq,
    output logic HLBren,
    output logic [3:0][7:0] MAC_in,
    output logic input_dv
);

    typedef enum logic [1:0] { 
        IDLE, RQ, RECEIVING, valid
    } state_t;
    state_t curstate, nxtstate;
    logic [3:0][7:0] buffer, buffernxt;

    always_ff @ (posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            curstate <= IDLE;
            buffer <= 'd0;
        end
        else begin
            curstate <= nxtstate;
            buffer <= buffernxt;
        end
    end

    always_comb begin 
        case(curstate)
            IDLE: nxtstate = input_rq ? RQ : IDLE;
            RQ: nxtstate = RECEIVING;
            RECEIVING: nxtstate = SPI_dv ? VALID : RECEIVING;
            VALID: nxtstate = input_rq ? RQ : VALID;
            default: nxtstate = IDLE;
        endcase
    end
    
    always_comb begin
        SPI_rq = 'd0;
        HLBren = 'd0;
        MAC_in = 'd0;
        input_dv = 'd0;
        buffernxt = buffer;
        case(curstate)
            RQ: begin
                SPI_rq = 'd1;
            end
            RECEIVING: begin
                HLBre = input_sel;
                buffernxt[3] = SPI_out[31:24] | {4'b0,HLBrdata[3]};
                buffernxt[2] = SPI_out[23:16]| {4'b0,HLBrdata[2]};
                buffernxt[1] = SPI_out[15:8] | {4'b0,HLBrdata[1]};
                buffernxt[0] = SPI_out[7:0] | {4'b0,HLBrdata[0]};
            end
            VALID: input_dv = 'd1;
        endcase
    end
    assign MAC_in = buffer;
endmodule

            
