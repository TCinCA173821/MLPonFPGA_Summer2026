module input_controller_tb;
    
	logic clk;
    logic n_rst;
    logic Irq;
    logic Itype;
    logic SPI_dv;
    logic [31:0] SPI_d;
    logic [15:0] HLBrdata;
    logic Id;
    logic [31:0] MAC_in;
    logic HLBren;
    logic HLBincr;
    logic SPI_rq;

    always #(10) clk++;
    input_controller DUT(.*);

    int SPI_rq_cnt = 0;
    int HLBren_cnt = 0;
    int HLBincr_cnt = 0;
    int cycles = 0;
    logic finished;
    logic [31:0] expected_MAC_in;

    always @(posedge clk) begin
        if(SPI_rq) SPI_rq_cnt++;
        if(HLBren) HLBren_cnt++;
        if(HLBincr) HLBincr_cnt++;
    end
    
    task reset();
      	n_rst = 1'b0;
      	repeat(2) @(posedge clk);
      	n_rst = 1'b1;
      	@(posedge clk);
      	#(1);
    endtask

    task test(
        input logic test_Itype,
        input logic [31:0] test_SPI_d,
        input logic [15:0] test_HLBrdata
    );
        SPI_rq_cnt = 0;
        HLBren_cnt = 0;
        HLBincr_cnt = 0;
        cycles = 0;
        finished = '0;
        
		SPI_dv = '1;
        SPI_d = test_SPI_d;
        HLBrdata = test_HLBrdata;
		Itype = test_Itype;

        Irq = '1;
        @(posedge clk);
        #(1);
        Irq = '0;

        //expected MAC_in logic
        for(int j = 0; j < 4; j++) begin
            expected_MAC_in[8*j +: 8] = {test_SPI_d[31-8*j -: 4], test_Itype ? test_HLBrdata[4*j +: 4] : test_SPI_d[27-8*j -: 4]};
        end

        while(!Id && cycles < 50) begin
            @(posedge clk);
            #(1);
            
            if(Id) finished = '1;
        end
        @(posedge clk);
        #(1);

        if(test_Itype) begin //from HLB
            if(finished && HLBren_cnt == 2 && HLBincr_cnt == 1 && SPI_rq_cnt == 1 && MAC_in == expected_MAC_in) begin
                $display("passed, HLBren cnt: %h, HLBincr_cnt: %h, SPI_rq_cnt: %h, MAC_in: %h", HLBren_cnt, HLBincr_cnt, SPI_rq_cnt, MAC_in);
            end else begin
                $display("passed, HLBren cnt: %h, HLBincr_cnt: %h, SPI_rq_cnt: %h, MAC_in: %h", HLBren_cnt, HLBincr_cnt, SPI_rq_cnt, MAC_in);
            end
        end else begin
            if(finished && HLBren_cnt == 0 && HLBincr_cnt == 0 && SPI_rq_cnt == 1 && MAC_in == expected_MAC_in) begin
                $display("passed, HLBren cnt: %h, HLBincr_cnt: %h, SPI_rq_cnt: %h, MAC_in: %h", HLBren_cnt, HLBincr_cnt, SPI_rq_cnt, MAC_in);
            end else begin
                $display("passed, HLBren cnt: %h, HLBincr_cnt: %h, SPI_rq_cnt: %h, MAC_in: %h", HLBren_cnt, HLBincr_cnt, SPI_rq_cnt, MAC_in);
            end
        end
    endtask
    
    initial begin
        $dumpfile("waveform.fst");
        $dumpvars(0, input_controller_tb.sv);
  	    n_rst = 1'b1;
  	    $timeformat(-9, 2, " ns", 20);
  	    reset();
  	    @(posedge clk);
  	    #(10); 

        //tests
        test('0, 32'h12345678, 16'hABCD); //no HLB input
        reset();
        test('1, 32'h12345678, 16'hABCD);
        
        $finish;
    end
endmodule
