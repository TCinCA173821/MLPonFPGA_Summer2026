module ARGMAXfsm(
    input logic clk,
    input logic n_rst,
    input logic ARGen,
    input logic ARGdv,
    output logic ARGd,
    output logic REN,
    output logic ARGSTR
);

    typedef enum logic [1:0] { 
        IDLE,
        READ,
        COMPARE
    } state_t;
    state_t curstate, nxtstate;
    logic [3:0] node, nxtnode;
    always_ff @ (posedge clk, negedge n_rst) begin
        if(!n_rst) begin
            curstate <= IDLE;
            node <= 'd0;
        end else begin
            curstate <= nxtstate;
            node <= nxtnode;
        end
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = ARGen ? READ : IDLE;
            READ: nxtstate = COMPARE;
            COMPARE: nxtstate = ARGdv ? (node == 'd9) ? IDLE: READ: COMPARE;
            default: nxtstate = IDLE;
        endcase
    end
    always_comb begin
        ARGd = 'd0;
        REN = 'd0;
        ARGSTR = 'd0;
        nxtnode = node;
        case(curstate)
            READ: REN = 'd1;
            COMPARE: begin 
                ARGSTR = 'd1;
                nxtnode = node + 'd1;
            end
        endcase
    end
endmodule
    
