`default_nettype none
// Empty top module

module top (
  // I/O ports
  input  logic hz100, reset,
  input  logic [20:0] pb,
  output logic [7:0] left, right,
         ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
  output logic red, green, blue,

  // UART ports
  output logic [7:0] txdata,
  input  logic [7:0] rxdata,
  output logic txclk, rxclk,
  input  logic txready, rxready
);

  logic start, SPI_dv, Done, MAC_s, MAC_l, HLBren, HLBincr, HLBwen, OLBincr, OLBwen, nxtpckt, ARG_s;
  logic [31:0] SPI_reg;
  logic [15:0] HLBrdata;
  logic [31:0] MAC_in;

  logic cs, sclk, nxtpckt_to_pi;
  logic [7:0] mosi;

  logic [63:0] MAC_out;
  logic [15:0] MAC_outrelu;

  logic [15:0] OLBrdata;
  logic [3:0] OLBrptr;

  logic [3:0] result;
  logic clk;

  assign clk = hz100;

  assign start = pb[9];
  assign cs = pb[10];
  assign sclk = pb[11];
  assign mosi = pb[19:12];


  assign left[0] = Done;
  assign left[1] = nxtpckt_to_pi;
  assign left[5:2] = result;
  

  controllertop main1(.*,.n_rst(!reset));
  SPI_mod spisys1(.*,.n_rst(!reset));
  genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_mac
          MAC MAC_inst (.*,.n_rst(!reset),.MAC_in(MAC_in[8*i +:8]),.MAC_out(MAC_out[8*i +:8]),.MAC_outrelu(MAC_outrelu[4*i +:4]));
        end
    endgenerate
  hidden_layer_buffer hlb1 (.*, .n_rst(!reset),.wen(HLBwen),.ren(HLBren),.incr(HLBincr),.in(MAC_outrelu),.out(HLBrdata));
  output_layer_buffer olb1 (.*,.n_rst(!reset),.wen(OLBwen),.r_inc(OLBincr),.in(MAC_out),.out_data(OLBrdata),.rptr(OLBrptr));
  argmax argmax1 (.*,.nrst(!reset),.start(ARG_s),.in(OLBrdata),.in_ptr(OLBrptr),.out(result));
  ssdec decoder1 (.digit(result),.ss0(ss0));
  
endmodule


module SPI_shiftreg (
    input logic sclk,
    input logic cs,
    input logic n_rst,
    input logic [7:0] mosi,
    output logic [31:0] SPI_reg
);

    logic [31:0] intreg, regnxt;

    always_ff @ (posedge sclk, negedge n_rst) begin
        if(!n_rst) intreg <= 32'b0;
        else intreg <= regnxt;
    end

    always_comb begin
        regnxt = cs ? {mosi, intreg[31:8]} : intreg;
    end
    assign SPI_reg = intreg;
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
        nxtpckt_to_pi = 1'b0;
        SPI_dv = 1'b0;
        case(curstate)
            RQ: nxtpckt_to_pi = 1'b1;
            PULSEDV: SPI_dv = 1'b1;
            default: begin
                nxtpckt_to_pi = 1'b0;
                SPI_dv = 1'b0;
            end
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
            syn1 <= 1'b0;
            syn2 <= 1'b0;
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


module ssdec (
    input  logic [3:0] digit,
    output logic [7:0] ss0
);

always_comb begin
    case (digit)
        4'd0: ss0 = 8'b00111111; // 0 active high to set active low just flip every bit
        4'd1: ss0 = 8'b00000110; // 1
        4'd2: ss0 = 8'b01011011; // 2
        4'd3: ss0 = 8'b01001111; // 3
        4'd4: ss0 = 8'b01100110; // 4
        4'd5: ss0 = 8'b01101101; // 5
        4'd6: ss0 = 8'b01111101; // 6
        4'd7: ss0 = 8'b00000111; // 7
        4'd8: ss0 = 8'b01111111; // 8
        4'd9: ss0 = 8'b01101111; // 9
        default: ss0 = 8'b0;
    endcase
end

endmodule


module output_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic r_inc,
	input logic [63:0] in,     // packed 4x16-bit (element k = in[16*k +: 16])
	output logic [15:0] out_data,
	output logic [3:0] rptr
);

logic [15:0] output_reg [0:11];
logic [3:0] wptr;

//write increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		wptr <= 4'd0;
	end else if (wen) begin
		if(wptr == 4'd8) begin
			wptr <= 4'd0;
		end else begin
			wptr <= (wptr + 4'd4);
		end
	end
end

//input
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		for (int i = 0; i < 12; i++) output_reg[i] <= 16'b0;
	end else if (wen) begin
		output_reg[wptr] <= in[16*3 +: 16];
		output_reg[wptr+4'd1] <= in[16*2 +: 16];
		output_reg[wptr+4'd2] <= in[16*1 +: 16];
		output_reg[wptr+4'd3] <= in[16*0 +: 16];
	end
end

//read increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		rptr <= 4'd0;
	end else if (r_inc) begin
		if(rptr == 4'd9) begin
			rptr <= 4'd0;
		end else begin
			rptr <= (rptr + 4'd1);
		end
	end
end

//output
assign out_data = output_reg[rptr];
endmodule


module controllertop(
    input logic clk,
    input logic n_rst,
    input logic start,
    input logic [15:0] HLBrdata,      // [1,2,3,4] order
    input logic SPI_dv,
    input logic [31:0] SPI_reg,
    output logic Done,
    output logic MAC_s,
    output logic MAC_l,
    output logic [31:0] MAC_in,      //[1,2,3,4] order
    output logic HLBren,
    output logic HLBincr,
    output logic HLBwen,
    output logic OLBincr,
    output logic OLBwen,
    output logic nxtpckt,
    output logic ARG_s
);
    logic ff1, ff2;
    always_ff @(posedge clk, negedge n_rst) begin // 2ff sync for start
        if(!n_rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= start;
            ff2 <= ff1;
        end
    end

    logic Len, Lsel, Ld, Aen, Ad, Men, Md, Irq, Itype, Id;
    logic [7:0] Miter;
    main_ctrlfsm main1 (.*, .start(ff2));
    layer_controller layer1(.*);
    MAC_controller mac1(.*);
    input_controller input1(.*,.SPI_d(SPI_reg),.SPI_rq(nxtpckt));
    argmax_controller arg1(.*);

endmodule

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
            count <= 8'd0;
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
            COMPUTE: nxtstate = (count == (Miter - 8'd1)) ? PULSEDONE : PULLINPUT;
            PULSEDONE: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
        nxtcount = (curstate == COMPUTE) ? count + 8'd1 : count;
    end

    always_comb begin
        Md = 1'b0;
        MAC_s = 1'b0;
        MAC_l = 1'b0;
        Irq = 1'b0;
        Itype = 1'b0;
        case(curstate) 
            PULLBIAS: Irq = 1'b1;
            LOADBIAS: MAC_l = 1'b1;
            PULLINPUT: begin 
                Itype = Lsel;
                Irq = 1'b1;
            end
            COMPUTE: MAC_s = 1'b1;
            PULSEDONE: Md = 1'b1;
        endcase
    end
endmodule


    
module layer_controller (
	input logic clk,
	input logic n_rst,
	input logic Len,
	input logic Lsel,
	input logic Md,
	output logic Men,
	output logic Ld,
	output logic HLBwen,
	output logic OLBwen,
	output logic [7:0] Miter
);

	logic [1:0] layer_cnt, next_cnt, total_layers;

	//states
	typedef enum logic [1:0] {
	IDLE,
	MAC,
	STORE,
	DONE
	} state_t;
	state_t state, next_state;

	always_comb begin
		case(state)
			IDLE: next_state = (Len) ? MAC : IDLE;
			MAC: next_state = (Md) ? STORE : MAC;
			STORE: next_state = (next_cnt == total_layers) ? DONE : MAC;
			DONE: next_state = IDLE;
			default: next_state = IDLE;
		endcase
	end

	always_ff @(posedge clk, negedge n_rst) begin
	if(!n_rst) begin
		state <= IDLE;
		layer_cnt <= 1'b0;
	end else begin
		state <= next_state;
		layer_cnt <= next_cnt;
	end
	end

	always_comb begin
	Men = 1'b0;
	Ld = 1'b0;
	next_cnt = layer_cnt;
	total_layers = (Lsel) ? 2'd2 : 2'd3;
	Miter = (Lsel) ? 8'd15 : 8'd195;
	OLBwen = 1'b0;
	HLBwen = 1'b0;
		
		case(state)
			IDLE: next_cnt = 1'b0;
			MAC: Men = 1'b1;
			STORE: begin
				next_cnt = layer_cnt + 2'd1;
				if(Lsel) OLBwen = 1'b1;
				else HLBwen = 1'b1;
			end
			DONE: Ld = 1'b1;
		endcase
	end
endmodule

module input_controller(
    input logic clk,
    input logic n_rst,
    input logic Irq,
    input logic Itype,
    input logic SPI_dv,
    input logic [31:0] SPI_d,
    input logic [15:0] HLBrdata,            //[1,2,3,4]
    output logic Id,
    output logic [31:0] MAC_in,      // [1,2,3,4]
    output logic HLBren,
    output logic HLBincr,
    output logic SPI_rq
);

    typedef enum logic [3:0] { 
        IDLE,
        RQ,
        RECEIVING,
        BUFFER,
        PULSEDONE
    } state_t;
    
    state_t curstate, nxtstate;
    logic [31:0] MAC_in_nxt;         // packed 4x8-bit

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) curstate <= IDLE;
        else curstate <= nxtstate;
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) MAC_in <= 32'b0;
        else MAC_in <= MAC_in_nxt;
    end

    always_comb begin
        case(curstate)
            IDLE: nxtstate = Irq ? RQ : IDLE;
            RQ: nxtstate = RECEIVING;
            RECEIVING: nxtstate = SPI_dv ? BUFFER : RECEIVING;
            BUFFER: nxtstate = PULSEDONE;
            PULSEDONE: nxtstate = IDLE;
            default: nxtstate = IDLE;
        endcase
    end

    always_comb begin
        MAC_in_nxt = MAC_in;
        HLBren = 1'b0;
        HLBincr = 1'b0;
        Id = 1'b0;
        SPI_rq = 1'b0;
        case(curstate)
            RQ: SPI_rq = 1'b1;
            RECEIVING: HLBren = Itype;
            BUFFER: begin 
                HLBren = Itype;
                for(int j = 0; j < 4; j++) begin
                    MAC_in_nxt[8*j +: 8] = {SPI_d[31-8*j -: 4], Itype ? HLBrdata[4*j +: 4] : SPI_d[27-8*j -: 4]};
                end
            end
            PULSEDONE: begin 
                Id = 1'b1;   
                HLBincr = Itype;
            end
        endcase
    end
endmodule


module argmax_controller (
	input logic clk,
	input logic n_rst,
	input logic Aen,
	output logic Ad,
	output logic OLBincr,
	output logic ARG_s
);

logic [3:0] node, next_node;
	
//states
typedef enum logic [1:0] {
	IDLE,
	RUN,
	INCR,
	DONE
} state_t;
state_t state, next_state;

//state change logic
always_comb begin
	case(state)
		IDLE: next_state = Aen ? RUN : IDLE;
		RUN: next_state = INCR;
		INCR: next_state = (node == 4'd9) ? DONE : RUN;
		DONE: next_state = IDLE;
		default: next_state = IDLE;
	endcase
end

//state and node num changes
always_ff @(posedge clk, negedge n_rst) begin
	if(!n_rst) begin
		state <= IDLE;
		node <= 4'd0;
	end else begin
		state <= next_state;
		node <= next_node;
	end
end

//signal updates
always_comb begin
	Ad = 1'b0;
	OLBincr = 1'b0;
	ARG_s = 1'b0;
	next_node = node;

	case(state)
		IDLE: next_node = 1'b0;
        RUN: ARG_s = 1'b1;
		INCR: begin
			OLBincr = 1'b1;
			next_node = node + 4'd1;
		end
		DONE: Ad = 1'b1;
	endcase
end
endmodule


module mixedsign4bitmult(
    input logic signed [3:0] signedin1,
    input logic [3:0] unsignedin2,
    output logic signed [15:0] signextendedout
);
    assign signextendedout = $signed(signedin1) * $signed({1'b0,unsignedin2});
endmodule

module addersigned16bit(
    input logic signed [15:0] in1,
    input logic signed [15:0] in2,
    output logic signed [15:0] out
); 
    assign out = in1 + in2;
endmodule

module accreg(
    input logic clk,
    input logic n_rst,
    input logic wen,
    input logic len,
    input logic signed [15:0] in,
    input logic [7:0] Lin,
    output logic signed [15:0] out
);

    logic signed [15:0] reg_val, reg_val_nxt;
    always_ff @ (posedge clk, negedge n_rst) begin
        if(!n_rst) reg_val <= 16'd0;
        else reg_val <= reg_val_nxt;
    end

    always_comb begin
        if (len) reg_val_nxt = $signed(Lin);
        else if(wen) reg_val_nxt = in;
        else reg_val_nxt = reg_val;
    end
    assign out = reg_val;
endmodule

module relu(
    input logic signed [15:0] in,
    output logic [3:0] out
); 
    always_comb begin
        if(in[15] == 1'b1) out = 4'd0;
        else if(|in[14:4]) out = 4'b1111;
        else out = in[3:0];
    end
endmodule

module MAC( 
    input logic clk,
    input logic n_rst,
    input logic [7:0] MAC_in,
    input logic MAC_s,
    input logic MAC_l,
    output logic signed [15:0] MAC_out,
    output logic [3:0] MAC_outrelu
);
    logic signed [15:0] mult_out, reg_in;
    
    mixedsign4bitmult mult1 (.signedin1($signed(MAC_in[7:4])),.unsignedin2(MAC_in[3:0]),.signextendedout(mult_out));
    addersigned16bit adder1 (.in1(mult_out),.in2(MAC_out),.out(reg_in));
    accreg buf_reg1 (.clk(clk),.n_rst(n_rst),.wen(MAC_s),.len(MAC_l),.in(reg_in),.Lin(MAC_in),.out(MAC_out));
    relu relu1 (.in(MAC_out),.out(MAC_outrelu));
endmodule


module hidden_layer_buffer (
	input logic clk,
	input logic nrst,
	input logic wen,
	input logic ren,
	input logic incr,
	input logic [15:0] in, //4x4 bits
	output logic [15:0] out
);

logic [15:0] mem_layers [3:0];
logic [1:0] ptr;

//ptr increment
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		ptr <= 2'b00;
	end else if (incr) begin
		ptr <= ptr + 1'b1;
	end
end

//write
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		for (int i = 0; i < 4; i++) mem_layers[i] <= 16'd0;
	end else if(wen) begin
		mem_layers <= {in, mem_layers[3], mem_layers[2], mem_layers[1]};
	end
end

//output
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out <= 16'b0;
	end else if (ren) begin
		out <= mem_layers[ptr];
	end
end
	
endmodule

module argmax (
	input logic clk,
	input logic nrst,
	input logic start,
	input logic signed [15:0] in,
	input logic [3:0] in_ptr,
	output logic [3:0] out
);

logic signed [15:0] out_reg;
logic load_en;

//register
always_ff @(posedge clk or negedge nrst) begin
	if(!nrst) begin
		out_reg <= 16'b0;
		out <= 4'b0;
	end else if(start && (in > out_reg)) begin
		out_reg <= in;
		out <= in_ptr;
	end
end
endmodule


