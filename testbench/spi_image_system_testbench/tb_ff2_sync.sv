'timescale 1ns/1ps

module tb_ff2_sync;
   
    logic rst_n;
    logic clk;
    logic in;
    logic out;

    int tests_passed = 0;
    int tests_total = 0;

    parameter CLK_PERIOD = 10;
    always #(CLK_PERIOD) clk++;

    ff2_sync DUT(
        .rst_n(rst_n),
        .clk(clk),
        .in(in),
        .out(out)
    );

//////////////////////////// Tasks ////////////////////////////

    task reset();
        rst_n = '0;
        in = '0;
        repeat(2) @(posedge clk);
        rst_n = '1;
        @(posedge clk);
        #(1);
        if (out !== 1'b0) $error("error where reset doesn't drive output to zero");
    endtask

    task drive_sync(input logic val);
        @(negedge clk);
        in = val;
    endtask

    task drive_async(input logic val);
        #($urandom_range(1,CLK_PERIOD -1));
        in = val;
    endtask

    task check_latency(input logic expected, input int cycles);
        repeat(cycles) @(posedge clk);
        #(1);
        tests_total++;
        if (out === expected) begin
            tests_passed++;
            $display("PASS: out=%b matches expected=%b after %0d cyles", out, expected, cycles);
        end else begin
            $error("FAIL: out=%b, expected=%b after %0d cycles", out, expected, cycles);
        end
    endtask

    task test_sync_latency(input logic val);
        drive_sync(val);
        @(posedge clk) #(1);
        if (out === val) $error("out changed too early before 2 clock cycles");
        check_latency(val,1);
    endtask

    task test_async_stability(input int num_toggles);
        for(int j = 0; j < num_toggles; j++) begin
            logic val;
            val = $urandom_range(0,1);
            drive_async(val);
            repeat(3) @(posedge clk);
            #(1);
            tests_total++;
            if ($isunknown(out)) begin
                $error("FAIL: went out X during async toggle #%0d", j);
            end else if (out === val) begin
                tests_passed++;
            end else begin
                @(posedge clk);
                #(1);
                if (out===val) 
                    tests_passed++;
                else
                    $error("FAIL: out=%b never settled to val=%b", out, val);
        end

    endtask




