
module SPI_fsm_tb;

    // TB Signals (connect to DUT)
    logic clk = 0, n_rst;
    logic sync_cs, nxtpckt, nxtpckt_to_pi, SPI_dv;

    // Clock generation
    always #(10) clk++;


    SPI_FSM DUT(
        .*,.sclk(clk)
    );
    

    task reset();
    begin
        n_rst = '0;
        repeat(2) @(posedge clk);
        n_rst = '1;
        @(posedge clk);
        #(1);
    end
    endtask

    task reset_signals();
    begin
        //target signals
        sync_cs = 0;
        nxtpckt = 0;
        nxtpckt_to_pi = 0;
        SPI_dv = 0;
    end
    endtask

    task run1(
    );
    begin
        nxtpckt = 1;
        @(posedge(nxtpckt_to_pi);
        #(30);
        sync_cs = 1;
        #(200);
        sync_cs = 0;
        fork
            begin
                @(posedge SPI_dv)
                $display("DV");
            end
            begin
                // Thread 2: The Timeout Timer
                #(1000); // Replace with your desired timeout value
                $display("Time out tb failed", $time);
            end
        join_any
        disable fork; // Stops the other thread that didn't finish
    end
    endtask


    initial begin
        
        $dumpfile("waveform.fst");
        $dumpvars(0, tb_copier_controller);

        n_rst = 1'b1;

        $timeformat(-9, 2, " ns", 20); // Set formatting for printing time

        reset_signals();
        reset();

        // execute the testbench
        run1();
        

        $finish;
    end

endmodule
