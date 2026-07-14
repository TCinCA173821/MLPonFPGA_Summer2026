module controllertop(
    input logic clk,
    input logic n_rst,
    input logic start,
    input logic [3:0] HLBrdata [3:0],
    input logic SPI_dv,
    input logic [31:0] SPI_reg,
    output logic Done,
    output logic MAC_s,
    output logic MAC_l,
    output logic signed [7:0] MAC_in [0:3],
    output logic HLBren,
    output logic HLBincr,
    output logic HLBwen,
    output logic OLBincr,
    output logic OLBwen,
    output logic nxtpckt,
    output logic ARG_s
);
    logic ff1, ff2;
    always_ff @(posedge clk, negedge n_rst) begin // 2ff sync for start
        if(n_rst) begin
            ff1 <= '0;
            ff2 <= '0;
        end else begin
            ff1 <= start;
            ff2 <= ff1;
        end
    end

    logic Len, Lsel, Ld, Aen, Ad, Men, Md, Irq, Itype, Id;
    logic [7:0] Miter
    main_ctrlfsm main1 (.*, .start(ff2))
    layer_controller layer1(.*);
    MAC_controller mac1(.*);
    input_controller input1(.*,.SPI_d(SPI_reg));
    argmax_controller arg1(.*);

endmodule
