module input_controller(
    input logic clk,
    input logic n_rst,
    input logic Irq,
    input logic Itype,
    input logic SPI_dv,
    input logic [31:0] SPI_d,
    input logic [15:0] HLBrdata,
    output logic Id,
    output logic [31:0] MAC_in,
    output logic HLBren,
    output logic HLBincr,
    output logic SPI_rq
);

    typedef enum logic [3:0] { 
        IDLE,
        RQ,
        RECEIVING,
        BUFFER,
        PULSEDONE
    } state_t;
    
    state_t curstate, nxtstate;
    logic [31:0] MAC_in_nxt;

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) MAC_in <= 32'b0;
        else MAC_in <= MAC_in_nxt;
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = Irq ? RQ : IDLE;
            RQ: nxtstate = RECEIVING;
            RECEIVING: nxtstate = SPI_dv ? BUFFER : RECEIVING;
            BUFFER: nxtstate = PULSEDONE;
            PULSEDONE: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
    end

    always_comb begin
        MAC_in_nxt = MAC_in;
        HLBren = 1'b0;
        HLBincr = 1'b0;
        Id = 1'b0;
        SPI_rq = 1'b0;
        case(curstate)
            RQ: SPI_rq = 1'b1;
            RECEIVING: HLBren = Itype;
            BUFFER: begin 
                HLBren = Itype;
                for(int j = 0; j < 4; j++) begin
                    MAC_in_nxt[8*j +: 8] = {SPI_d[31-8*j -: 4], Itype ? HLBrdata[4*j +: 4] : SPI_d[27-8*j -: 4]};
                end
            end
            PULSEDONE: begin 
                Id = 1'b1;   
                HLBincr = Itype;
            end
        endcase
    end
endmodule


