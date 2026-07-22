module controllertop_tb;
    logic clk = 0;
    logic n_rst;
    logic start;
    logic [15:0] HLBrdata;
    logic SPI_dv;
    logic [31:0] SPI_reg;
    logic Done;
    logic MAC_s;
    logic MAC_l;
    logic [31:0] MAC_in;
    logic HLBren;
    logic HLBincr;
    logic HLBwen;
    logic OLBincr;
    logic OLBwen;
    logic nxtpckt;
    logic ARG_s;

    controllertop DUT(.*);
    always #(10) clk++;

    int nxtpckt_cnt = 0;
    int cycles = 0;
    logic finished;

    //update counters
    always @(posedge clk) begin
        if(nxtpckt) nxtpck_cnt++;
        if(Done) finished = 1'b1;
    end

    //data valid response sim
    always @(posedge clk) begin
        if(nxtpckt) begin
            repeat(2) @(posedge clk);
            SPI_dv <= 1'b1;
            @(posedge clk);
            SPI_dv <= 1'b0;
        end
    end
    
    task reset();
      	n_rst = 1'b0;
      	repeat(2) @(posedge clk);
      	n_rst = 1'b1;
      	@(posedge clk);
      	#(1);
    endtask

    task test();
        start = 1'b1;
        @(posedge clk);
        #(1);
        start = 1'b0;

        while(!finished && cycles < 100000) begin
            cycles++;
            @(posedge clk);
            #(1);
        end

        if(finished) begin
            $display("done asserted, cycle count: %d, nxtpckt count: %d", cycles, nxtpckt_count);
        end else begin
            $display("done NOT asserted, cycle count: %d, nxtpckt count: %d", cycles, nxtpckt_count);
        end
    endtask
    
    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, MAC_controller_tb.sv);
      	n_rst = 1'b1;
      	$timeformat(-9, 2, " ns", 20);
      	reset();
      	@(posedge clk);
      	#(10);  

        test();
        
        $finish;
    end
endmodule
