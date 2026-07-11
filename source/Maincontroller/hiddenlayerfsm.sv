module hiddenlayerFSM(
    input logic clk,
    input logic n_rst,
    input logic HLEN,
    input logic DV,
    output logic HLD,
    output logic store,
    output logic mulstart,
    output logic [9:0] iter1
);
    typedef enum logic [1:0] { 
        IDLE,
        MAC,
        STORE
     } state_t;
    
    state_t curstate, nxtstate;

    logic [1:0] node,nxtnode;

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) begin
            curstate <= IDLE;
            node <= 'd0;
        end
        else begin 
            curstate <= nxtstate;
            node <= nxtnode;
        end
    end

    always_comb begin
        nxtnode = node;
        case(curstate) 
            IDLE: nxtstate = HLEN ? MAC : IDLE;
            MAC: nxtstate = DV ? STORE : MAC;
            STORE: begin 
                nxtstate = (node == 'd3) ? IDLE : MAC;
                nxtnode = node + 'd1;
            end
            default: nxtstate = IDLE;
        endcase
    end


    assign iter1 = 'd195;
    assign store = (curstate == STORE);
    assign mulstart = (curstate == MAC);
    assign HLD = (curstate == IDLE)
endmodule
