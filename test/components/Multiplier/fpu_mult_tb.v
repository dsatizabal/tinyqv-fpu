`timescale 1ns / 1ps
`default_nettype none

module fpu_mult_tb;

    reg req_in;
    reg [15:0] a;
    reg [15:0] b;
    reg valid_in;
    wire [15:0] result;
    wire valid_out;
    wire ack_out;

    // Instantiate the pipelined multiplier
    async_fpu_mult uut (
        .req_in(req_in),
        .a(a),
        .b(b),
        .result(result),
        .valid_out(valid_out),
        .ack_out(ack_out)
    );

endmodule
