`timescale 1ns / 1ps
`default_nettype none

module fpu_mult_tb;

    reg         clk;
    reg         rst_n;
    reg         valid_in;
    reg  [31:0] a;
    reg  [31:0] b;
    wire        valid_out;
    wire [31:0] result;

    // Instantiate the pipelined multiplier
    fpu_mult_pipelined uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .valid_out(valid_out),
        .result(result)
    );

endmodule
