module storefsm(
    input logic clk,
    input logic n_rst,
    input logic store,
    input logic state,
    output logic HLBincr,
    output logic OLBincr,
    output logic HLBwen,
    output logic OLBwen
);

    typedef enum logic [1:0] { 
        IDLE,
        WRITE,
        INCR
    } state_t;

    state_t curstate, nxtstate;
    
    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = store ? WRITE : IDLE;
            WRITE: nxtstate = INCR;
            INCR: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
    end

    always_comb begin
        OLBincr = 'd0;
        HLBincr = 'd0;
        OLBwen = 'd0;
        HLBwen = 'd0;
        if(state) begin
            OLBincr = (curstate == INCR);
            OLBwen = (curstate == WRITE);
        end else begin
            HLBincr = (curstate == INCR);
            HLBwen = (curstate == WRITE);
        end
    end
    