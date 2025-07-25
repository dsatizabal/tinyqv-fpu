`timescale 1ns / 1ps
`default_nettype none

module fpu_add_tb;
    reg  [31:0] a, b;
    wire [31:0] result;

    fpu_add uut (
        .a(a),
        .b(b),
        .result(result)
    );
endmodule
