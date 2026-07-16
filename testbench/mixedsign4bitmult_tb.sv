module mixedsign4bitmult_tb;

  logic signed [3:0] signedin1;
  logic [3:0] unsignedin2;
  logic signed [15:0] signextendedout;

  int tests_passed = 0;
  int total_tests = 0;

  mixedsign4bitmult DUT (
    .*;
  );
