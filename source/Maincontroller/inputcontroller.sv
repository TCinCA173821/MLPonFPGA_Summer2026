module input_controller(
    input logic clk,
    input logic n_rst,
    input logic Irq,
    input logic Itype,
    input logic SPI_dv,
    input logic [31:0] SPI_d,
    input logic [3:0] HLBrdata [0:3],
    output logic Id,
    output logic signed [7:0] MAC_in [0:3],
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
    logic signed [7:0] MAC_in_nxt [0:3];

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) MAC_in <= '0;
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
        int j;
        MAC_in_nxt = MAC_in;
        HLBren = '0;
        HLBincr = '0;
        Id = '0;
        SPI_rq = '0;
        case(curstate)
            RQ: SPI_rq = '1;
            RECEIVING: HLBren = Itype;
            BUFFER: begin 
                HLBren = Itype;
                for(j = 0; j < 4; j++) begin
                    MAC_in_nxt[j] = $signed({SPI_d[31-8*j:28-8*j], Itype ? HLBrdata[3-j] :SPI_d[27-8*j:24-8*j]});
                end
            end
            PULSEDONE: begin 
                Id = '1;   
                HLBincr = Itype;
            end
        endcase
    end
endmodule


