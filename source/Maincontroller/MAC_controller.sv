module MAC_controller(
    input logic clk,
    input logic n_rst,
    input logic Men,
    input logic [7:0] Miter,
    input logic Id,
    input logic Lsel,
    output logic Md,
    output logic MAC_s,
    output logic MAC_l,
    output logic Irq,
    output logic Itype
); 
    typedef enum logic [2:0] { 
        IDLE,
        PULLBIAS,
        LOADBIAS,
        PULLINPUT,
        COMPUTE,
        PULSEDONE
    } state_t;

    state_t curstate, nxtstate;
    logic [7:0] count, nxtcount;

    always_ff @ (posedge clk, negedge n_rst) begin
        if(!n_rst) begin
            curstate <= IDLE;
            count <= 'd0;
        end else begin
            curstate <= nxtstate;
            count <= nxtcount;
        end
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = Men ? PULLBIAS : IDLE;
            PULLBIAS: nxtstate = Id ? LOADBIAS : PULLBIAS;
            LOADBIAS: nxtstate = PULLINPUT;
            PULLINPUT: nxtstate = Id ? COMPUTE : PULLINPUT;
            COMPUTE: nxtstate = (count == (Miter - 'd1)) ? PULSEDONE : PULLINPUT;
            PULSEDONE: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
        nxtcount = (curstate == COMPUTE) ? count + 'd1 : count;
    end

    always_comb begin
        Md = '0;
        MAC_s = '0;
        MAC_l = '0;
        Irq = '0;
        Itype = '0;
        case(curstate) 
            PULLBIAS: Irq = '1;
            LOADBIAS: MAC_l = '1;
            PULLINPUT: begin 
                Itype = Lsel;
                Irq = '1;
            end
            COMPUTE: MAC_s = '1;
            PULSEDONE: Md = '1;
        endcase
    end
endmodule


    