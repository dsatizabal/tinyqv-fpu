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
    wire sign_a        = a[31];
    wire [7:0] exp_a   = a[30:23];
    wire [22:0] mant_a = a[22:0];
    wire [23:0] frac_a = (exp_a == 0) ? {1'b0, mant_a} : {1'b1, mant_a};

    wire sign_b        = b[31];
    wire [7:0] exp_b   = b[30:23];
    wire [22:0] mant_b = b[22:0];
    wire [23:0] frac_b = (exp_b == 0) ? {1'b0, mant_b} : {1'b1, mant_b};

    wire is_nan_a = (exp_a == 8'hFF) && (mant_a != 0);
    wire is_nan_b = (exp_b == 8'hFF) && (mant_b != 0);
    wire is_inf_a = (exp_a == 8'hFF) && (mant_a == 0);
    wire is_inf_b = (exp_b == 8'hFF) && (mant_b == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);

    wire [47:0] product = frac_a * frac_b;
    wire [8:0] raw_exp = exp_a + exp_b - 8'd127;
    wire norm_shift = product[47];
    wire [7:0] norm_exp = norm_shift ? raw_exp[7:0] + 1 : raw_exp[7:0];
    wire [22:0] norm_mant = norm_shift ? product[46:24] : product[45:23];
    wire result_sign = sign_a ^ sign_b;

    wire [31:0] computed_result = {result_sign, norm_exp, norm_mant};
    wire [31:0] inf_result = {result_sign, 8'hFF, 23'b0};
    wire [31:0] nan_result = 32'h7FC00000;

    assign result =
        is_nan_a | is_nan_b                          ? nan_result :
        (is_inf_a & is_zero_b) | (is_zero_a & is_inf_b) ? nan_result :
        is_inf_a | is_inf_b                          ? inf_result :
        is_zero_a | is_zero_b                        ? {result_sign, 31'b0} :
                                                       computed_result;

endmodule
