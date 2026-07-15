module SPI_shiftreg (
    input logic sclk,
    input logic cs,
    input logic n_rst,
    input logic [7:0] mosi
    output logic [31:0] SPI_reg
);

    logic [31:0] reg, regnxt;

    alawys_ff @ (posedge sclk, negedge n_rst) begin
        if(!n_rst) reg <= '0;
        else reg <= regnxt;
    end

    always_comb begin
        regnxt = cs ? {mosi, reg[31:8]} : reg;
    end
endmodule

module SPI_FSM(
    input logic clk,
    input logic n_rst,
    input logic sync_cs,
    input logic nxtpckt,
    output logic nxtpckt_to_pi,
    output logic SPI_dv
);
    typedef enum logic [1:0] { 
        IDLE,
        RQ,
        RECEIVE,
        PULSEDV
    } state_t;

    state_t curstate, nxtstate;

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = nxtpckt ? RQ : IDLE;
            RQ: nxtstate = sync_cs ? RECEIVE : RQ;
            RECEIVE: nxtstate = sync_cs ? RECEIVE : PULSEDV;
            PULSEDV: nxtstate = IDLE;
        endcase
    end

    always_comb begin
        nxtpckt_to_pi = '0;
        SPI_dv = '0;
        case(curstate)
            RQ: nxtpckt_to_pi = '1;
            PULSEDV: SPI_dv = '1;
        endcase
    end
endmodule

module dualffsync (
    input logic clk,
    input logic n_rst,
    input logic async_in,
    output logic sync_out
);
    logic syn1, syn2;
    always_ff @ (posedge clk, negedge n_rst) begin
        if(!n_rst) begin
            syn1 <= '0;
            syn2 <= '0;
        end else begin
            syn1 <= async_in;
            syn2 <= syn1;
        end
    end
    assign sync_out = syn2;
endmodule

module SPI_mod (
    input logic clk,
    input logic n_rst,
    input logic nxtpckt,
    input logic cs,
    input logic sclk,
    input logic [7:0] mosi,
    output logic nxtpckt_to_pi,
    output logic SPI_dv,
    output logic [31:0] SPI_reg
);
    logic sync_cs;
    SPI_shiftreg spireg(.*);
    dualffsync sync_cs_f_fsm(.clk(clk),.n_rst(n_rst),.async_in(cs),.sync_out(sync_cs));
    SPI_FSM controler(.*);
endmodule
