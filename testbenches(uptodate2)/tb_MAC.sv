module tb_MAC;
    logic clk = 0, n_rst;
    logic [7:0] MAC_in;
    logic MAC_s, MAC_l;
    logic signed [15:0] MAC_out;
    logic [3:0] MAC_outrelu;

    int errors = 0;
    int checks = 0;
    logic signed [15:0] model_acc;

    always #(10) clk++;

    MAC DUT (
        .clk(clk), .n_rst(n_rst), .MAC_in(MAC_in),
        .MAC_s(MAC_s), .MAC_l(MAC_l),
        .MAC_out(MAC_out), .MAC_outrelu(MAC_outrelu)
    );

    function automatic logic [3:0] relu_model(input logic signed [15:0] v);
        if (v[15]) relu_model = 4'd0;
        else if (|v[14:4]) relu_model = 4'b1111;
        else relu_model = v[3:0];
    endfunction

    task automatic reset();
        n_rst = 0; MAC_s = 0; MAC_l = 0; MAC_in = 0; model_acc = 0;
        repeat (2) @(posedge clk);
        n_rst = 1;
        @(posedge clk);
        #(1);
    endtask

    task automatic load_bias(input logic signed [7:0] b);
        MAC_in = b; MAC_l = 1; MAC_s = 0;
        @(posedge clk);
        #(1);
        MAC_l = 0;
        model_acc = signed'(b);
    endtask

    task automatic accumulate(input logic signed [3:0] a, input logic [3:0] u);
        MAC_in = {a, u}; MAC_s = 1; MAC_l = 0;
        @(posedge clk); #1;
        MAC_s = 0;
        model_acc = model_acc + (signed'(a) * signed'({1'b0, u}));
    endtask

    task automatic check(input string msg);
        checks++;
        if (MAC_out !== model_acc) begin
            errors++;
            $display("FAIL: %s => MAC_out got %0d exp %0d", msg, MAC_out, model_acc);
        end else if (MAC_outrelu !== relu_model(model_acc)) begin
            errors++;
            $display("FAIL: %s => relu got %0d exp %0d", msg, MAC_outrelu, relu_model(model_acc));
        end else begin
            $display("PASS: %s => acc=%0d relu=%0d", msg, MAC_out, MAC_outrelu);
        end
    endtask

    initial begin
        $dumpfile("tb_MAC.vcd");
        $dumpvars(0, tb_MAC);

        reset();
        check("after reset");

        load_bias(-8'sd100); check("bias -100");
        accumulate( 4'sd4, 4'd9);  check("acc 4*9");
        accumulate(-4'sd5, 4'd14); check("acc -5*14");
        accumulate( 4'sd7, 4'd11); check("acc 7*11");
        accumulate( 4'sd2, 4'd2);  check("acc 2*2");

        reset();
        load_bias(8'sd0); check("bias 0");
        for (int k = 0; k < 6; k++) begin
            accumulate(4'sd7, 4'd15);
            check($sformatf("posacc step %0d", k));
        end
        
        reset();
        load_bias($random); check("rand bias");
        for (int k = 0; k < 30; k++) begin
            accumulate($random, $random);
            check($sformatf("rand step %0d", k));
        end

        $display("\n=== tb_MAC: %0d/%0d checks passed, %0d errors ===",
                 checks - errors, checks, errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $finish;
    end
endmodule
