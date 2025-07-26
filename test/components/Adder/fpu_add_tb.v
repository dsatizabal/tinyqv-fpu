`timescale 1ns / 1ps
`default_nettype none

module fpu_add_tb;
    reg clk;
    reg rst_n;
    reg [31:0] a;
    reg [31:0] b;
    reg valid_in;
    wire [31:0] result;
    wire valid_out;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz clock (10 ns period)

    // DUT instantiation
    fpu_add_pipelined uut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .valid_in(valid_in),
        .result(result),
        .valid_out(valid_out)
    );

endmodule
