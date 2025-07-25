`timescale 1ns / 1ps
`default_nettype none

module fpu_mult_tb;
    reg  [31:0] a, b;
    wire [31:0] result;

    fpu_mult uut (
        .a(a),
        .b(b),
        .result(result)
    );
endmodule
