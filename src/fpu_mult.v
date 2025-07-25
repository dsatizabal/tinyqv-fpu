/*
 * IEEE 754 Floating Point Multiplier (Single-Precision)
 * Combinational version
 * Author: Diego Satizabal, 2025
 */

`default_nettype none

module fpu_mult (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result
);
    // Unpack operands
    wire sign_a       = a[31];
    wire [7:0] exp_a  = a[30:23];
    wire [23:0] frac_a = {1'b1, a[22:0]};  // implied 1 as per IEEE 754

    wire sign_b       = b[31];
    wire [7:0] exp_b  = b[30:23];
    wire [23:0] frac_b = {1'b1, b[22:0]};  // implied 1 as per IEEE 754

    // Multiply mantissas: 24-bit × 24-bit = 48-bit
    wire [47:0] product = frac_a * frac_b;

    // Add exponents and subtract bias (127)
    wire [8:0] raw_exp = exp_a + exp_b - 8'd127;

    // Normalize mantissa (product is 48-bit, top 2 bits indicate shift)
    wire norm_shift = product[47]; // if 1, we need to shift right by 1
    wire [7:0] norm_exp = norm_shift ? (raw_exp + 1) : raw_exp[7:0];
    wire [22:0] norm_mantissa = norm_shift ? product[46:24] : product[45:23];

    // Result sign: XOR of input signs
    wire result_sign = sign_a ^ sign_b;

    // Pack result
    assign result = {result_sign, norm_exp, norm_mantissa};

endmodule
