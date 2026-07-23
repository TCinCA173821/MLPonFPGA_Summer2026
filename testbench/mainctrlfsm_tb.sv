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
        n_rst = 1'b0;
        repeat(2) @(posedge clk);
        n_rst = 1'b1;
        @(posedge clk);
        #(1);
    end
    endtask

    task test();
    begin
        start = 1'b1;
        @(posedge clk);
        #(1);
        start = 1'b0;
        Ld = 1'b1;
        if(Len && !Lsel) begin
            $display("hidden layer successful: Len: %h, Lsel: %h", Len, Lsel);
        end else begin
            $display("hidden layer failed: Len: %h, Lsel: %h", Len, Lsel);
        end
    
        @(posedge clk);
        #(1);
        if(Len && Lsel) begin
            $display("output layer successful: Len: %h, Lsel: %h", Len, Lsel);
        end else begin
            $display("output layer failed: Len: %h, Lsel: %h", Len, Lsel);
        end

        @(posedge clk);
        #(1);
        Ad = 1'b1;
        if(Aen) begin
            $display("argmax successful: Aen: %h", Aen);
        end else begin
            $display("argmax failed: Aen: %h", Aen);
        end

        @(posedge clk);
        #(1);
        if(Done) begin
            $display("finished successfully");
        end else begin
            $display("finish failed");
        end
    end
    endtask

    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, mainctrlfsm_tb.sv);
  	    n_rst = 1'b1;
  	    $timeformat(-9, 2, " ns", 20);
  	    reset();
  	    @(posedge clk);
  	    #(10); 
        
        test();
      
        $finish;
    end
endmodule
