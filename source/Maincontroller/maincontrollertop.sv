module MAINcontrollertop (
    input logic clk, 
    input logic n_rst,
    input logic start,
    input logic [31:0] SPI_out,
    input logic SPI_dv,
    input logic [3:0][3:0] HLBrdata,
    input logic MAC_dv,
    input logic ARGdv,
    output logic infdone,
    output logic nxtpckt,
    output logic HLBren,
    output logic [3:0][7:0] MAC_in,
    output logic MAC_start,
    output logic HLBwen,
    output logic OLBwen,
    output logic OLren,
    output logic ARGmax_start
);

    logic HLen, OLen, ARGen, HLd, OLd, ARGd;
    logic state;

    logic store1, mulstart1;
    logic store2, mulstart2;
    logic store, mulstart;
    logic [9:0] iter1, iter2;
    logic multiplierfsmDV;

    logic input_dv, input_rq, input_sel;
    logic SPI_rq, SPI_to_input_dv;
    logic [31:0] SPI_to_input_data;

    assign store = store1 | store2;
    assign mulstart = mulstart1 | mulstart2;

    maincontroller overallstate (.*);
    hiddenlayerFSM hiddenlayer(.*);
    outputlayerFSM outputlayer(.*);
    ARGMAXfsm ARgmax (.*);
    MULcontroller multiplierctrl(.*);
    storefsm storagefsm (.*);
    INPUTfsm inputfsm(.*);
    SPIRQcontroller spirequester (.*);

endmodule