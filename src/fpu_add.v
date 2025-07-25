/*
 * IEEE 754 Floating Point Adder (Single-Precision)
 * Combinational version
 * Author: Diego Satizabal, 2025
 */

`default_nettype none

module fpu_add (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result
);
    // Unpack operands
    wire sign_a     = a[31];
    wire [7:0] exp_a = a[30:23];
    wire [23:0] frac_a = {1'b1, a[22:0]};  // implied leading 1 as per IEEE 754

    wire sign_b     = b[31];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] frac_b = {1'b1, b[22:0]};

    // Compare exponents and align mantissas
    wire [7:0] exp_diff = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);
    wire [7:0] exp_large = (exp_a > exp_b) ? exp_a : exp_b;

    wire [23:0] aligned_a = (exp_a > exp_b) ? frac_a : (frac_a >> exp_diff);
    wire [23:0] aligned_b = (exp_b > exp_a) ? frac_b : (frac_b >> exp_diff);

    // For now, assume both are positive (same sign only)
    // Extend to 25 bits to detect overflow
    wire [24:0] sum = aligned_a + aligned_b;

    // Normalize (if overflow, shift right and increase exponent)
    wire [7:0] norm_exp = sum[24] ? (exp_large + 1) : exp_large;
    wire [22:0] norm_mantissa = sum[24] ? sum[23:1] : sum[22:0];

    // Pack result (always positive for now)
    assign result = {1'b0, norm_exp, norm_mantissa};

endmodule
