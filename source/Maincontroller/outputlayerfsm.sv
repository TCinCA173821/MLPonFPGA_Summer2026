module outputlayerFSM(
    input logic clk,
    input logic n_rst,
    input logic OLen,
    input logic multiplierfsmDV,
    output logic OLd,
    output logic store2,
    output logic mulstart2,
    output logic [9:0] iter2
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
            IDLE: nxtstate = OLen ? MAC : IDLE;
            MAC: nxtstate = multiplierfsmDV ? STORE : MAC;
            STORE: begin 
                nxtstate = (node == 'd2) ? IDLE : MAC;
                nxtnode = node + 'd1;
            end
            default: nxtstate = IDLE;
        endcase
    end


    assign iter1 = 'd15;
    assign store2 = (curstate == STORE);
    assign mulstart2 = (curstate == MAC);
    assign OLd = (curstate == IDLE)
endmodule