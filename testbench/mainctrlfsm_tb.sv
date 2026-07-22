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
    always #(10) clk++;

    task reset();
    begin
        n_rst = 1'b1;
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
        Len = 0;
        Lsel = 0;
        Aen = 0;
        Done = 0;
    end
    endtask

    task test_run(
    );
    begin
        start = 1;
        
    end
    endtask


    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, mainctrlfsm_tb.sv);
        n_rst = 1'b1;
        $timeformat(-9,2,"ns", 20);
        reset();
        rst_signals();

        test_run();

        $finish;
    end
endmodule