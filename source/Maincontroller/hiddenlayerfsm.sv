module hiddenlayerFSM(
    input logic clk,
    input logic n_rst,
    input logic HLen,
    input logic multiplierfsmDV,
    output logic HLd,
    output logic store1,
    output logic mulstart1,
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
            IDLE: nxtstate = HLen ? MAC : IDLE;
            MAC: nxtstate = multiplierfsmDV ? STORE : MAC;
            STORE: begin 
                nxtstate = (node == 'd3) ? IDLE : MAC;
                nxtnode = node + 'd1;
            end
            default: nxtstate = IDLE;
        endcase
    end


    assign iter1 = 'd195;
    assign store1 = (curstate == STORE);
    assign mulstart1 = (curstate == MAC);
    assign HLd = (curstate == IDLE)
endmodule
