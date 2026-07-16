
module SPI_mod_tb;

    // TB Signals (connect to DUT)
    logic clk = 0, n_rst, sclk = 0;
    logic [7:0] mosi;
    logic cs, nxtpckt, nxtpckt_to_pi, SPI_dv;
    logic [31:0] SPI_reg;

    logic [31:0] expectedpckt;
    // TODO: (optional) declare any other debugging-related
    // metadata signals you want here.
    // Adding things like a test number, or a string containing
    // the name of the test can be helpful for discerning when tests
    // start/stop when viewed in the waveforms.

    // Clock generation
    always #(10) clk++;
    always #(40) sclk++;
    SPI_mod DUT(
        .*
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

    /*
    * reset_signals
    *
    * Set all signals to a "neutral" value. Can be helpful between tests.
    */
    task reset_signals();
    begin
        //target signals
        mosi = 0;
        cs = 0;
        nxtpckt = 0;
        nxtpckt_to_pi = 0;
        SPI_dv = 0;
        SPI_reg = 0;
    end
    endtask

    task writepckt(
        logic [31:0]pkt
    );
    begin
        cs = 1'b1;
        for(int i = 0; i < 4; i++) begin
            mosi = pkt[31-8*i -:8];
            @(posedge sclk);
            #(1);
        end
        #(1);
        cs = 1'b0;
    end
    endtask

    task check_valid(
        logic [31:0] pkt
    );
    begin
        if(pkt == SPI_reg)
            $display("passed");
    end
    endtask



    task run1(
        logic [31:0]pkt
    );
    begin

        nxtpckt = 1;
        @(posedge nxtpckt_to_pi);
        writepckt(pkt);
        fork
            begin
                @(posedge SPI_dv)
                check_valid(pkt);
            end
            begin
                // Thread 2: The Timeout Timer
                #(1000); // Replace with your desired timeout value
                $display("Time out tb failed", $time);
            end
        join_any
        disable fork;
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
        run1({32'h00000000});
        run1({32'h11111111});
        run1({32'hFFFFFFFF});
        run1({32'hAAAAAAAA});
        

        $finish;
    end

endmodule
