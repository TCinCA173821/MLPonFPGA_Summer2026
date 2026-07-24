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
	//int MAC_s_cnt = 0;
	//int MAC_l_cnt = 0;
	//int HLBren_cnt = 0;
	//int HLBwen_cnt = 0;
	//int OLBwen_cnt = 0;
	//int ARG_s_cnt = 0;
	//int HLBincr_cnt = 0;
	//nt OLBincr_cnt = 0;
    int cycles = 0;
    logic finished;
	logic nxtpckt_d;

    //update counters
    always_ff @(posedge clk) begin
		//if(MAC_s) MAC_s_cnt++;
		//if(MAC_l) MAC_l_cnt++;
		//if(HLBren) HLBren_cnt++;
		//if(HLBwen) HLBwen_cnt++;
		//if(OLBwen) OLBwen_cnt++;
		//if(ARG_s) ARG_s_cnt++;
		//if(OLBincr) OLBincr_cnt++;
        if(Done) finished <= 1'b1;

		//nxtpckt_d <= nxtpckt;		
		//if(nxtpckt && !nxtpckt_d) begin
		//	nxtpckt_cnt <= nxtpckt_cnt + 1;
		//end
    end

	always_ff @(posedge nxtpckt) nxtpckt_cnt++;

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
		SPI_dv = 1'b1;

        while(!finished && cycles < 100000) begin
            cycles++;
			if(nxtpckt && !nxtpckt_d) $display("nxtpckt_cnt: %d, cycle count: %d", nxtpckt_cnt, cycles);
            @(posedge clk);
            #(1);
        end

        if(finished) begin
            $display("done asserted, cycle count: %d, nxtpckt count: %d", cycles, nxtpckt_cnt);
			//$display("HLBwen cnt: %d, HLBren cnt: %d, OLBwen cnt: %d, ARGs cnt: %d", HLBwen_cnt, HLBren_cnt, OLBwen_cnt, ARG_s_cnt);
			//$display("OLBincr cnt: %d, HLBincr cnt: %d", OLBincr_cnt, HLBincr_cnt);
        end else begin
            $display("done NOT asserted, cycle count: %d, nxtpckt count: %d", cycles, nxtpckt_cnt);
        end
    endtask
    
    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, controllertop_tb.sv);
      	n_rst = 1'b1;
      	$timeformat(-9, 2, " ns", 20);
      	reset();
      	@(posedge clk);
      	#(10);  

        test();
        
        $finish;
    end
endmodule
