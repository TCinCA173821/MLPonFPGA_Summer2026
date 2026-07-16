module mixedsign4bitmult_tb;

  logic signed [3:0] signedin1;
  logic [3:0] unsignedin2;
  logic signed [15:0] signextendedout;

  int tests_passed = 0;
  int total_tests = 0;

  mixedsign4bitmult DUT (
    .*;
  );

  initial begin
    $dumpfile("waveform.fst");
    $dumpvars(0, mixedsign4bitmult_tb);
    
    for (int i = -8; i < 8; i++) begin
      for (int j = 0; j < 16; j++) begin
        signedin1 = 4'(i);
        unsignedin2 = 4'(j);
        #(1);

        total_tests++;
        if(signextendedout == signed'(4'(i)) * signed'({1'b0, 4'(j)}) begin
          tests_passed++;
        end
      end
    end
    $display("%d/%d tests passed", tests_passed, total_tests);
           
    $finish
  end
endmodule
