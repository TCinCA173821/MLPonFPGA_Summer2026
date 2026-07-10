

module spi_fsm(
    input logic rst_n,
    input logic [7:0] mosi_sync,
    input logic cs_sync,
    input logic sclk_sync,
    input logic clk,
    output logic [7:0] mosi_out,
    output logic shiftR,
    output logic dataValid
);
    // edge detection (complete)
    logic sclk_prev; // memory to keep track of previous sclk state
    logic pulse; // pulse sent to counter to increment cycle count
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            sclk_prev <= 1'b0;
        else
            sclk_prev <= sclk_sync;
    end
    assign pulse = ~sclk_prev & sclk_sync;

    // cycle counter (complete)
    logic [1:0] cycle_cnt; // number of cycles for receiving next_state
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            cycle_cnt <= 1'b0;
        else if (pulse)
            cycle_cnt <= cycle_cnt + 1;
    end


    // state encoding (complete)
    typedef enum logic [1:0] {
        IDLE = 2'b00, // Idle
        REC = 2'b01, // Receiving
        DATAVAL = 2'b11 // data valid
    } state_t;
    state_t current_state, next_state;


    // state register (sequential) (complete)
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end


    // next-state logic (combinational) (incomplete)
    always_comb begin
        next_state = current_state;
        case(current_state)
            IDLE: 
                if(cs_sync) next_state = REC;
            REC:
                if (cycle_cnt != 2'd3) next_state = REC;
                else if (cycle_cnt == 3) next_state = DATAVAL;
            DATAVAL: 
                next_state = IDLE;
            default: next_state = IDLE;
        endcase

    end

    // output logic (combinational) (incomplete)
    always_comb begin
        shiftR = 1'b0;
        dataValid = 1'b0;
        mosi_out = 8'b0;

        case (current_state)
            IDLE: begin
                dataValid = 1'b0;
                shiftR = 1'b0;
                mosi_out = 8'b0;
            end
            REC: begin
                dataValid = 1'b0;
                shiftR = 1'b1;
                mosi_out = mosi_sync;

            end
            DATAVAL: begin
                dataValid = 1'b1;
                shiftR = 1'b0;
                mosi_out = 8'b0;
            end
            default: begin
                shiftR = 1'b0;
                dataValid = 1'b0;
                mosi_out = 8'b0;                
            end
        endcase

    end
endmodule


////////////////////////////////this module is basically 3 2ff synchronizers for sclk, cs, and mosi//////////////////////////////////////////////////

module sync(
    input logic rst_n,
    input logic [7:0] mosi_in,
    input logic clk,
    input logic sclk_in,
    input logic cs_in,
    output logic [7:0] mosi_out,
    output logic cs_out,
    output logic sclk_out
);
    //mosi[7:0] synchronization (mosi_sync)
    genvar i;
    generate
        for(i=0; i < 8; i++) begin : mosi_sync
            ff2_sync mosi_ff2 (.rst_n(rst_n), .clk(clk), .in(mosi_in[i]), .out(mosi_out[i]));
        end
    endgenerate

    //cs synchronization
    ff2_sync cs_ff2 (.rst_n(rst_n), .clk(clk), .in(cs_in), .out(cs_out));

    // sclk synchronization
    ff2_sync sclk_ff2 (.rst_n(rst_n), .clk(clk), .in(sclk_in), .out(sclk_out));

endmodule


/////////////////////////////////////////////2ff synchronizer//////////////////////////////////////////////////////////

module ff2_sync(
    input logic rst_n,
    input logic clk,
    input logic in,
    output logic out
);
    logic ff1, ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin   
            ff1 <= in;
            ff2 <= ff1;
        end
    end
    assign out = ff2;
endmodule



/////////////////////////////////////////shift register//////////////////////////////////////////////////////////////////

module shiftreg #(parameter width = 32) (
    input logic rst_n,
    input logic clk,
    input logic shiftR,
    input logic [7:0] in,
    output logic [width -1:0] out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out <= 0;
        else begin
            if(shiftR) 
                out <= {in, out[width - 1: 8]};
            else
                out <= out;
        end
    end

endmodule