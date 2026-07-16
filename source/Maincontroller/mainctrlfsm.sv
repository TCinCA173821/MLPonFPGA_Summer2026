module main_ctrlfsm(
    input logic clk,
    input logic n_rst,
    input logic start,
    input logic Ld,
    input logic Ad,
    output logic Len,
    output logic Lsel,
    output logic Aen,
    output logic Done
);

    typedef enum logic [2:0] { 
        IDLE,
        HIDDENLAYER,
        OUTPUTLAYER,
        ARGMAX,
        PULSEDONE
    } state_t;

    state_t curstate, nxtstate;

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = start ? HIDDENLAYER : IDLE;
            HIDDENLAYER: nxtstate = Ld ? OUTPUTLAYER : HIDDENLAYER;
            OUTPUTLAYER: nxtstate = Ld ? ARGMAX : OUTPUTLAYER;
            ARGMAX: nxtstate = Ad ? PULSEDONE : ARGMAX;
            PULSEDONE: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
    end

    always_comb begin
        Len = 1'b0;
        Lsel = 1'b0;
        Aen = 1'b0;
        Done = 1'b0;
        case(curstate)
            HIDDENLAYER: Len = 1'b1;
            OUTPUTLAYER: begin
                Len = 1'b1;
                Lsel = 1'b1;
            end
            ARGMAX: Aen = 1'b1;
            PULSEDONE: Done = 1'b1;
        endcase
    end
endmodule
