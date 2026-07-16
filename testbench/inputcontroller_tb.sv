
module tb_inputcontroller;

    // TB Signals (connect to DUT)
    logic clk = 0, n_rst;
    logic [15:0] HLBrdata
    logic [31:0] SPI_reg, MAC_in;
    logic Irq, Itype, Id, SPIrq, SPIdv, HLBren, HLBincr, HLBwen, OLBincr,
            OLBwen, nxtpckt, ARG_s;

    logic [31:0] fake_SPI_reg;
    logic [15:0] fake_HLBrdata;
    // TODO: (optional) declare any other debugging-related
    // metadata signals you want here.
    // Adding things like a test number, or a string containing
    // the name of the test can be helpful for discerning when tests
    // start/stop when viewed in the waveforms.

    // Clock generation
    always #(10) clk++;

    controllertop DUT(
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
        HLBrdata = 0;
        SPI_reg = 0;
        MAC_in = 0;
        start = 0;

        //fake memory signals
        mem_ready = 0;
        mem_rdata = '0;

    end
    endtask

    /*
    * fake_transaction
    *
    * TODO: Complete fake_transaction, a task that creates a transaction to step through memcpy controller.
    *       You should use the tasks created for you. Make sure to set the "fake memory" signals.
    */
    task fake_transaction ();
    begin
        
    // Your code here!

    end
    endtask

    task request_copy (
        input logic [7:0] rm_HLBrdata,
        input logic [7:0] wm_SPI_reg
    );
    begin
        int rc_cycles = 0;
        HLBrdata = rm_HLBrdata;
        SPI_reg = wm_SPI_reg;

        while (!(Done == 1'b0 && mem_wen == 1'b0 && mem_ren == 1'b0 
            && mem_addr == 8'b0 && mem_wdata == 8'hFF)) begin
            if (rc_cycles >= 15) begin
                $error("Output signals not reset for new copy operation: Done: %b, mem_wen: %b, mem_ren: %b, mem_addr: %h, mem_wdata: %h",
                       Done, mem_wen, mem_ren, mem_addr, mem_wdata);
                return;
            end
            @(posedge clk)
            rc_cycles++;
        end

        start = 1'b1;
        $display("Copying Started...");
        @(posedge clk)
        @(posedge clk)
        start = 1'b0;

    end
    endtask

    task read_mem(
        input logic [7:0] rm_HLBrdata
    );
    begin
        int rm_cycles = 0;

        MAC_in = 8'b1; // hardcoded 1 byte r/w
        mem_rdata = 8'hA8; // hardcoded A8 read
        
        while (!(Done == 1'b0 && mem_wen == 1'b0 && mem_ren == 1'b1 
                && mem_addr == rm_HLBrdata && mem_wdata == 8'hFF)) begin
            if (rm_cycles >= 15) begin
                $error("Timeout: output signals not set properly for a read operation, exceeded 15 cycles");
                return;
            end
            @(posedge clk)
            rm_cycles++;
        end

        @(posedge clk)
        mem_ready = 1'b1;
        $display("Reading byte at %h on cycle %d", mem_addr, rm_cycles);
        @(posedge clk)
        mem_ready = 1'b0;

    end
    endtask

    task write_mem(
        logic [7:0] wm_SPI_reg,
    );
    begin
        int wm_cycles = 0;
        while (!(Done == 1'b0 && mem_wen == 1'b1 && mem_ren == 1'b0 
            && mem_addr == wm_SPI_reg && mem_wdata == fake_byte)) begin
            if (wm_cycles >= 15) begin
                $error("Timeout: output signals not set properly for a read operation, exceeded 15 cycles");
                return;
            end
            @(posedge clk)
            wm_cycles++;
        end
        
        $display("Wrote byte at %h on cycle %d", mem_addr, wm_cycles);

    end
    endtask

    task check_complete(
    );
    begin
        int cc_cycles = 0;
        while (!(Done == 1'b1 && mem_wen == 1'b0 && 
            mem_ren == 1'b0 && mem_wdata == 8'hFF)) begin
            if (cc_cycles >= 15) begin
                $error("Timeout: output signals not set properly once Done");
                return;
            end
            @(posedge clk)
            cc_cycles++;
        end
        $display("Finished MEMCPY");
        $display("MEMCPY Transaction Successful!");
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
        fake_transaction();

        $finish;
    end

endmodule