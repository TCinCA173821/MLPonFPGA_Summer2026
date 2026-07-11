module storefsm(
    input logic clk,
    input logic n_rst,
    input logic store,
    input logic state,
    output logic HLBwen,
    output logic OLBwen
);

    typedef enum logic { 
        IDLE,
        WRITE
    } state_t;

    state_t curstate, nxtstate;
    
    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = store ? WRITE : IDLE;
            WRITE: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
    end

    always_comb begin
        OLBwen = 'd0;
        HLBwen = 'd0;
        if(state) begin
            OLBwen = (curstate == WRITE);
        end else begin
            HLBwen = (curstate == WRITE);
        end
    end
endmodule