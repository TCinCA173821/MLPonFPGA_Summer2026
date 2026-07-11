module INPUTfsm(
    input logic clk,
    input logic n_rst,
    input logic input,
    input logic Rq,
    input logic [31:0] SPI_data,
    input logic SPI_dv,
    input logic [3:0][3:0] HLdata,
    output logic SPI_Rq,
    output logic HLBren,
    output logic [3:0][7:0] MAC_in,
    output logic DV
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
            IDLE: nxtstate = Rq ? RQ : IDLE;
            RQ: nxtstate = RECEIVING;
            RECEIVING: nxtstate = SPI_dv ? VALID : RECEIVING;
            VALID: nxtstate = Rq ? RQ : VALID;
            default: nxtstate = IDLE;
        endcase
    end
    
    always_comb begin
        SPI_Rq = 'd0;
        HLBren = 'd0;
        MAC_in = 'd0;
        DV = 'd0;
        buffernxt = buffer;
        case(curstate)
            RQ: begin
                SPI_Rq = 'd1;
            end
            RECEIVING: begin
                HLBre = input;
                buffernxt[3] = SPI_data[31:24] | {4'b0,HLdata[3]};
                buffernxt[2] = SPI_data[23:16]| {4'b0,HLdata[2]};
                buffernxt[1] = SPI_data[15:8] | {4'b0,HLdata[1]};
                buffernxt[0] = SPI_data[7:0] | {4'b0,HLdata[0]};
            end
            VALID: DV = 'd1;
        endcase
    end
    assign MAC_in = buffer;
endmodule

            
