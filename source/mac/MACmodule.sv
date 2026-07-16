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
        if(in[15] == 1'b1) out = 'd0;
        else if(|in[14:4]) out = 'b1111;
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


