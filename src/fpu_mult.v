/*
 * IEEE 754 Floating Point Multiplier (Single-Precision)
 * 3-stage pipelined version
 * Author: Diego Satizabal, 2025
 */

`default_nettype none

module fpu_mult_pipelined (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg         valid_out,
    output reg  [31:0] result
);

    // === Stage 1: Field Extraction and Special Case Detection ===
    reg        s1_valid;
    reg        s1_sign_a, s1_sign_b;
    reg [7:0]  s1_exp_a, s1_exp_b;
    reg [22:0] s1_mant_a, s1_mant_b;
    reg [23:0] s1_frac_a, s1_frac_b;
    reg        s1_is_nan_a, s1_is_nan_b;
    reg        s1_is_inf_a, s1_is_inf_b;
    reg        s1_is_zero_a, s1_is_zero_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
        end else begin
            s1_valid   <= valid_in;
            s1_sign_a  <= a[31];
            s1_sign_b  <= b[31];
            s1_exp_a   <= a[30:23];
            s1_exp_b   <= b[30:23];
            s1_mant_a  <= a[22:0];
            s1_mant_b  <= b[22:0];
            s1_frac_a  <= (a[30:23] == 8'b0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
            s1_frac_b  <= (b[30:23] == 8'b0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};
            s1_is_nan_a  <= (a[30:23] == 8'hFF) && (a[22:0] != 0);
            s1_is_nan_b  <= (b[30:23] == 8'hFF) && (b[22:0] != 0);
            s1_is_inf_a  <= (a[30:23] == 8'hFF) && (a[22:0] == 0);
            s1_is_inf_b  <= (b[30:23] == 8'hFF) && (b[22:0] == 0);
            s1_is_zero_a <= (a[30:23] == 8'b0) && (a[22:0] == 0);
            s1_is_zero_b <= (b[30:23] == 8'b0) && (b[22:0] == 0);
        end
    end

    // === Stage 2: Multiply and Compute Exponent ===
    reg        s2_valid;
    reg [47:0] s2_product;
    reg [8:0]  s2_raw_exp;
    reg        s2_result_sign;
    reg        s2_norm_shift;
    reg        s2_is_nan;
    reg        s2_is_inf_a, s2_is_inf_b;
    reg        s2_is_zero_a, s2_is_zero_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 1'b0;
        end else begin
            s2_valid        <= s1_valid;
            s2_result_sign  <= s1_sign_a ^ s1_sign_b;
            s2_product      <= s1_frac_a * s1_frac_b;
            s2_raw_exp      <= s1_exp_a + s1_exp_b - 8'd127;
            s2_norm_shift   <= s1_frac_a[23] & s1_frac_b[23]; // conservative shift flag
            s2_is_nan       <= s1_is_nan_a | s1_is_nan_b | ((s1_is_inf_a | s1_is_inf_b) & (s1_is_zero_a | s1_is_zero_b));
            s2_is_inf_a     <= s1_is_inf_a;
            s2_is_inf_b     <= s1_is_inf_b;
            s2_is_zero_a    <= s1_is_zero_a;
            s2_is_zero_b    <= s1_is_zero_b;
        end
    end

    // === Stage 3: Normalize and Pack Result ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result    <= 32'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= s2_valid;
            if (s2_valid) begin
                if (s2_is_nan) begin
                    result <= 32'h7FC00000;
                end else if (s2_is_inf_a | s2_is_inf_b) begin
                    result <= {s2_result_sign, 8'hFF, 23'b0};
                end else if (s2_is_zero_a | s2_is_zero_b) begin
                    result <= {s2_result_sign, 31'b0};
                end else begin
                    reg [7:0]  norm_exp;
                    reg [22:0] norm_mant;

                    if (s2_product[47]) begin
                        norm_mant = s2_product[46:24];
                        norm_exp  = s2_raw_exp[7:0] + 1;
                    end else begin
                        norm_mant = s2_product[45:23];
                        norm_exp  = s2_raw_exp[7:0];
                    end

                    result <= {s2_result_sign, norm_exp, norm_mant};
                end
            end
        end
    end

endmodule
