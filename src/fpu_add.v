/*
 * IEEE 754 Half-Precision (16-bit) Floating Point Adder/Subtractor
 * 5-stage pipelined version for reduced area
 * Maintains 32-bit interface for compatibility
 * Author: Diego Satizabal, 2025
 */

`default_nettype none

module fpu_add_pipelined (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg         valid_out,
    output reg  [31:0] result
);

    // Stage 1
    reg        s1_valid;
    reg        s1_sign_a, s1_sign_b;
    reg [4:0]  s1_exp_a, s1_exp_b;
    reg [10:0] s1_mant_a, s1_mant_b;
    reg        s1_is_nan_a, s1_is_nan_b;
    reg        s1_is_inf_a, s1_is_inf_b;
    reg [15:0] s1_nan_result;

    wire [15:0] in_a = a[15:0];
    wire [15:0] in_b = b[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 0;
        end else begin
            s1_valid     <= valid_in;
            s1_sign_a    <= in_a[15];
            s1_sign_b    <= in_b[15];
            s1_exp_a     <= in_a[14:10];
            s1_exp_b     <= in_b[14:10];
            s1_mant_a    <= (in_a[14:10] == 5'b0) ? {1'b0, in_a[9:0]} : {1'b1, in_a[9:0]};
            s1_mant_b    <= (in_b[14:10] == 5'b0) ? {1'b0, in_b[9:0]} : {1'b1, in_b[9:0]};
            s1_is_nan_a  <= (in_a[14:10] == 5'b11111) && (in_a[9:0] != 0);
            s1_is_nan_b  <= (in_b[14:10] == 5'b11111) && (in_b[9:0] != 0);
            s1_is_inf_a  <= (in_a[14:10] == 5'b11111) && (in_a[9:0] == 0);
            s1_is_inf_b  <= (in_b[14:10] == 5'b11111) && (in_b[9:0] == 0);
            s1_nan_result <= 16'h7E00;
        end
    end

    // Stage 2
    reg        s2_valid;
    reg [4:0]  s2_exp_large;
    reg [10:0] s2_aligned_a, s2_aligned_b;
    reg        s2_sign_a, s2_sign_b;
    reg        s2_signed_op;
    reg        s2_is_nan, s2_is_conflicting_inf, s2_is_inf_a, s2_is_inf_b;
    reg [15:0] s2_nan_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 0;
        end else begin
            s2_valid <= s1_valid;
            s2_sign_a <= s1_sign_a;
            s2_sign_b <= s1_sign_b;
            s2_signed_op <= (s1_sign_a != s1_sign_b);
            s2_is_nan <= s1_is_nan_a | s1_is_nan_b;
            s2_is_inf_a <= s1_is_inf_a;
            s2_is_inf_b <= s1_is_inf_b;
            s2_is_conflicting_inf <= s1_is_inf_a & s1_is_inf_b & (s1_sign_a != s1_sign_b);
            s2_nan_result <= s1_nan_result;

            if (s1_exp_a > s1_exp_b) begin
                s2_exp_large <= s1_exp_a;
                s2_aligned_a <= s1_mant_a;
                s2_aligned_b <= s1_mant_b >> (s1_exp_a - s1_exp_b);
            end else begin
                s2_exp_large <= s1_exp_b;
                s2_aligned_a <= s1_mant_a >> (s1_exp_b - s1_exp_a);
                s2_aligned_b <= s1_mant_b;
            end
        end
    end

    // Stage 3
    reg        s3_valid;
    reg [11:0] s3_sum;
    reg        s3_result_sign;
    reg [4:0]  s3_exp;
    reg        s3_is_nan, s3_is_conflicting_inf, s3_is_inf_a, s3_is_inf_b;
    reg        s3_sign_a, s3_sign_b;
    reg [15:0] s3_nan_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid <= 0;
        end else begin
            s3_valid <= s2_valid;
            s3_exp <= s2_exp_large;
            s3_is_nan <= s2_is_nan;
            s3_is_conflicting_inf <= s2_is_conflicting_inf;
            s3_is_inf_a <= s2_is_inf_a;
            s3_is_inf_b <= s2_is_inf_b;
            s3_sign_a <= s2_sign_a;
            s3_sign_b <= s2_sign_b;
            s3_nan_result <= s2_nan_result;

            if (s2_signed_op) begin
                if (s2_aligned_a >= s2_aligned_b) begin
                    s3_sum <= s2_aligned_a - s2_aligned_b;
                    s3_result_sign <= s2_sign_a;
                end else begin
                    s3_sum <= s2_aligned_b - s2_aligned_a;
                    s3_result_sign <= s2_sign_b;
                end
            end else begin
                s3_sum <= s2_aligned_a + s2_aligned_b;
                s3_result_sign <= s2_sign_a;
            end
        end
    end

    // Stage 4
    reg        s4_valid;
    reg [4:0]  s4_exp;
    reg [10:0] s4_frac;
    reg        s4_result_sign;
    reg        s4_is_nan, s4_is_conflicting_inf, s4_is_inf_a, s4_is_inf_b;
    reg        s4_sign_a, s4_sign_b;
    reg [15:0] s4_nan_result;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid <= 0;
        end else begin
            s4_valid <= s3_valid;
            s4_is_nan <= s3_is_nan;
            s4_is_conflicting_inf <= s3_is_conflicting_inf;
            s4_is_inf_a <= s3_is_inf_a;
            s4_is_inf_b <= s3_is_inf_b;
            s4_sign_a <= s3_sign_a;
            s4_sign_b <= s3_sign_b;
            s4_nan_result <= s3_nan_result;

            if (s3_sum == 0) begin
                s4_exp <= 0;
                s4_frac <= 0;
                s4_result_sign <= 0;
            end else if (s3_sum[11]) begin
                s4_frac <= s3_sum[11:1];
                s4_exp <= s3_exp + 1;
                s4_result_sign <= s3_result_sign;
            end else begin
                s4_frac = s3_sum[10:0];
                s4_exp = s3_exp;
                s4_result_sign <= s3_result_sign;
                for (i = 10; i >= 0; i = i - 1) begin
                    if (s4_frac[10]) begin
                        i = -1;
                    end else begin
                        s4_frac = s4_frac << 1;
                        s4_exp = s4_exp - 1;
                    end
                end
            end
        end
    end

    // Stage 5
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            valid_out <= s4_valid;
            if (s4_valid) begin
                if (s4_is_nan || s4_is_conflicting_inf) begin
                    result <= {16'b0, s4_nan_result};
                end else if (s4_is_inf_a) begin
                    result <= {16'b0, {s4_sign_a, 5'b11111, 10'b0}};
                end else if (s4_is_inf_b) begin
                    result <= {16'b0, {s4_sign_b, 5'b11111, 10'b0}};
                end else begin
                    result <= {16'b0, {s4_result_sign, s4_exp, s4_frac[9:0]}};
                end
            end
        end
    end

endmodule
