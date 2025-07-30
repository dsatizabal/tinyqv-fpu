`timescale 1ns / 1ps

module fpu_add_tb;

    reg clk = 0;
    reg rst_n = 0;
    reg [31:0] a;
    reg [31:0] b;
    reg valid_in;
    wire [31:0] result;
    wire valid_out;

    // Instantiate the DUT
    fpu_add_pipelined dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .valid_in(valid_in),
        .result(result),
        .valid_out(valid_out)
    );
endmodule
