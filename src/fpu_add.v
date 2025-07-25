/*
 * IEEE 754 Floating Point Adder/Subtractor (Single-Precision)
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
    wire sign_a       = a[31];
    wire [7:0] exp_a  = a[30:23];
    wire [22:0] mant_a = a[22:0];
    wire [23:0] frac_a = (exp_a == 0) ? {1'b0, mant_a} : {1'b1, mant_a}; // Subnormal check

    wire sign_b       = b[31];
    wire [7:0] exp_b  = b[30:23];
    wire [22:0] mant_b = b[22:0];
    wire [23:0] frac_b = (exp_b == 0) ? {1'b0, mant_b} : {1'b1, mant_b};

    // Special cases
    wire is_nan_a = (exp_a == 8'hFF) && (mant_a != 0);
    wire is_nan_b = (exp_b == 8'hFF) && (mant_b != 0);
    wire is_inf_a = (exp_a == 8'hFF) && (mant_a == 0);
    wire is_inf_b = (exp_b == 8'hFF) && (mant_b == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);
    wire [31:0] nan_result = 32'h7FC00000;

    // Exponent alignment
    wire [7:0] exp_diff = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);
    wire [7:0] exp_large = (exp_a > exp_b) ? exp_a : exp_b;

    wire [23:0] aligned_a = (exp_a > exp_b) ? frac_a : (frac_a >> exp_diff);
    wire [23:0] aligned_b = (exp_b > exp_a) ? frac_b : (frac_b >> exp_diff);

    wire signed_op = (sign_a != sign_b);
    wire [24:0] sum = signed_op ? 
                      ((aligned_a >= aligned_b) ? (aligned_a - aligned_b) : (aligned_b - aligned_a)) :
                      (aligned_a + aligned_b);

    wire result_sign = signed_op ? 
                       ((aligned_a >= aligned_b) ? sign_a : sign_b) :
                       sign_a;

    // Normalize result
    reg [7:0] final_exp;
    reg [23:0] final_frac;
    reg [4:0] shift;

    always @(*) begin
        if (sum[24]) begin
            final_exp = exp_large + 1;
            final_frac = sum[24:1];
        end else begin
            shift = 0;
            final_frac = sum[23:0];
            final_exp = exp_large;

            while (final_frac[23] == 0 && final_exp > 0 && final_frac != 0) begin
                final_frac = final_frac << 1;
                final_exp = final_exp - 1;
                shift = shift + 1;
            end
        end
    end

    wire [22:0] final_mantissa = final_frac[22:0];
    wire is_zero_result = (sum == 0);

    wire [31:0] computed_result = is_zero_result ? 32'b0 : {result_sign, final_exp, final_mantissa};

    assign result =
        is_nan_a | is_nan_b                     ? nan_result :
        is_inf_a & is_inf_b & (sign_a != sign_b)? nan_result :
        is_inf_a                                ? {sign_a, 8'hFF, 23'b0} :
        is_inf_b                                ? {sign_b, 8'hFF, 23'b0} :
                                                  computed_result;

endmodule
