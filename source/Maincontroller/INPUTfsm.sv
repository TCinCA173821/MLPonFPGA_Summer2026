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
        IDLE, RQ, RECEIVING
    } state_t;
    state_t curstate, nxtstate;

    always_ff @ (posedge clk, negedge n_rst) begin
        if (!n_rst)
            curstate <= IDLE;
        else 
            curstate <= nxtstate;
    end

    always_comb begin 
        case(curstate)
            IDLE: nxtstate = Rq ? RQ : IDLE;
            RQ: nxtstate = RECEIVING;
            RECEIVING: nxtstate = SPI_dv ? IDLE : RECEIVING;
            default: nxtstate = IDLE;
        endcase
    end
    
    always_comb begin
        SPI_Rq = 'd0;
        HLBren = 'd0;
        MAC_in = 'd0;
        DV = 'd0;
        case(curstate)
            IDLE: DV ='d1;
            RQ: begin
                SPI_Rq = 'd1;
            end
            RECEIVING: begin
                HLBre = input;
                MAC_in[3] = SPI_data[31:24] | HLdata[3];
                MAC_in[2] = SPI_data[23:16]| HLdata[2];
                MAC_in[1] = SPI_data[15:8] | HLdata[1];
                MAC_in[0] = SPI_data[7:0] | HLdata[0];
            end
        endcase
    end
endmodule

            
