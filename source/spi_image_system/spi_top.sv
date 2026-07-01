module spi_top(
    input logic MOSI[7:0],
    input logic cs_in,
    input logic SCLK,
    input logic result[4:0],
    input logic infdone,
    output logic datavalid,
    output logic spiout[15:0],
    output logic MISO
);
    
endmodule