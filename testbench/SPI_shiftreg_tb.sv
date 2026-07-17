
module SPI_shiftreg_tb;

    // TB Signals (connect to DUT)
    logic clk = 0, n_rst;
    logic [7:0] mosi;
    logic cs;
    logic [31:0] SPI_reg;

    logic [31:0] expectedpckt;

    // Clock generation
    always #(10) clk++;



    SPI_shiftreg DUT(
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
        mosi = 0;
        cs = 0;
    end
    endtask

    task writepckt(
        logic [31:0]pkt
    );
    begin
        cs = 1'b1;
        for(int i = 0; i < 4; i++) begin
            mosi = pkt[31-8*i -:8];
            @(posedge clk);
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

        writepckt(pkt);
        #(10);
        check_valid(pkt);
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
