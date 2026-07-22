module mainctrlfsm_tb;
    logic clk = 0, n_rst;
    logic start;
    logic Ld;
    logic Ad;
    logic Len;
    logic Lsel;
    logic Aen;
    logic Done;

    main_ctrlfsm DUT(
        .clk(clk), .n_rst(n_rst), .start(start), .Ld(Ld), .Ad(Ad),
        .Len(Len), .Lsel(Lsel), .Aen(Aen), .Done(Done)
    );
    always #(10) clk = ~clk;

    task reset();
    begin
        n_rst = 1'b0;
        repeat(2) @(posedge clk);
        n_rst = 1'b1;
        @(posedge clk);
        #(1);
    end
    endtask

    task rst_signals();
    begin
        start = 0;
        Ld = 0;
        Ad = 0;
    end
    endtask


    task automatic curstate_check(
        input string name_state,
        input logic [2:0] exp_state,
        input logic exp_Len, 
        input logic exp_Lsel, 
        input logic exp_Aen, 
        input logic exp_Done);
        begin
            @(posedge clk);
            #1;
            if(DUT.curstate !== exp_state|| 
                Len !== exp_Len ||
                Lsel !== exp_Lsel ||
                Aen !== exp_Aen ||
                Done !== exp_Done
            ) 
            begin
                $error("ERROR: state: %b(exp: %b), Len: %b(exp: %b), Lsel: %b(exp: %b), Aen: %b(exp: %b), Done: %b(exp: %b)", 
                DUT.curstate, exp_state, Len, exp_Len, Lsel, exp_Lsel, Aen, exp_Aen, Done, exp_Done);
            end
            else if (DUT.curstate === exp_state) begin
                $display("STATE: %s, PASSED", name_state);
            end
        end
    endtask

    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, mainctrlfsm_tb);
        reset();
        rst_signals();
        curstate_check("IDLE", DUT.IDLE, 1'b0, 1'b0, 1'b0, 1'b0);
        start =  1;
        curstate_check("HIDDEN LAYER", DUT.HIDDENLAYER, 1'b1, 1'b0, 1'b0, 1'b0);
        Ld = 1;
        curstate_check("OUTPUT LAYER", DUT.OUTPUTLAYER, 1'b1, 1'b1, 1'b0, 1'b0);
        Ld = 1;
        curstate_check("ARGMAX", DUT.ARGMAX, 1'b0, 1'b0, 1'b1, 1'b0);
        Ad = 1;
        curstate_check("PULSE DONE", DUT.PULSEDONE, 1'b0, 1'b0, 1'b0, 1'b1);
        // check  if loops back to idle
        curstate_check("IDLE", DUT.IDLE, 1'b0, 1'b0, 1'b0, 1'b0);
        $timeformat(-9,2,"ns", 20);
        $finish;
    end
endmodule