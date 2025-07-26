/*
 * IEEE 754 Floating Point Adder/Subtractor (Single-Precision)
 * 3-stage pipelined version with special case handling
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

    // Stage 1: Unpack and align
    reg        s1_valid;
    reg        s1_sign_a, s1_sign_b;
    reg [7:0]  s1_exp_a, s1_exp_b, s1_exp_large, s1_exp_diff;
    reg [23:0] s1_frac_a, s1_frac_b;
    reg        s1_signed_op;
    reg        s1_is_nan_a, s1_is_nan_b;
    reg        s1_is_inf_a, s1_is_inf_b;
    reg [31:0] s1_nan_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
        end else begin
            s1_valid    <= valid_in;
            s1_sign_a   <= a[31];
            s1_sign_b   <= b[31];
            s1_exp_a    <= a[30:23];
            s1_exp_b    <= b[30:23];
            s1_frac_a   <= (a[30:23] == 8'b0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
            s1_frac_b   <= (b[30:23] == 8'b0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};
            s1_exp_diff <= (a[30:23] > b[30:23]) ? (a[30:23] - b[30:23]) : (b[30:23] - a[30:23]);
            s1_exp_large<= (a[30:23] > b[30:23]) ? a[30:23] : b[30:23];
            s1_signed_op<= (a[31] != b[31]);

            s1_is_nan_a   <= (a[30:23] == 8'hFF) && (a[22:0] != 0);
            s1_is_nan_b   <= (b[30:23] == 8'hFF) && (b[22:0] != 0);
            s1_is_inf_a   <= (a[30:23] == 8'hFF) && (a[22:0] == 0);
            s1_is_inf_b   <= (b[30:23] == 8'hFF) && (b[22:0] == 0);
            s1_nan_result <= 32'h7FC00000; // quiet NaN
        end
    end

    // Stage 2: Add/Subtract
    reg        s2_valid;
    reg        s2_result_sign;
    reg [7:0]  s2_exp_large;
    reg [24:0] s2_sum;
    reg        s2_is_nan;
    reg        s2_is_conflicting_inf;
    reg        s2_is_inf_a, s2_is_inf_b;
    reg        s2_sign_a, s2_sign_b;
    reg [31:0] s2_nan_result;
    reg [23:0] aligned_a, aligned_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 1'b0;
        end else begin
            s2_valid     <= s1_valid;
            s2_exp_large <= s1_exp_large;
            s2_is_nan    <= s1_is_nan_a | s1_is_nan_b;
            s2_is_conflicting_inf <= s1_is_inf_a & s1_is_inf_b & (s1_sign_a != s1_sign_b);
            s2_is_inf_a  <= s1_is_inf_a;
            s2_is_inf_b  <= s1_is_inf_b;
            s2_sign_a    <= s1_sign_a;
            s2_sign_b    <= s1_sign_b;
            s2_nan_result<= s1_nan_result;

            // Align
            aligned_a = (s1_exp_a > s1_exp_b) ? s1_frac_a : (s1_frac_a >> s1_exp_diff);
            aligned_b = (s1_exp_b > s1_exp_a) ? s1_frac_b : (s1_frac_b >> s1_exp_diff);

            if (s1_signed_op) begin
                if (aligned_a >= aligned_b) begin
                    s2_sum <= aligned_a - aligned_b;
                    s2_result_sign <= s1_sign_a;
                end else begin
                    s2_sum <= aligned_b - aligned_a;
                    s2_result_sign <= s1_sign_b;
                end
            end else begin
                s2_sum <= aligned_a + aligned_b;
                s2_result_sign <= s1_sign_a;
            end
        end
    end

    // Stage 3: Normalize and pack
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result     <= 32'b0;
            valid_out  <= 1'b0;
        end else begin
            valid_out <= s2_valid;

            if (s2_valid) begin
                if (s2_is_nan || s2_is_conflicting_inf) begin
                    result <= s2_nan_result;
                end else if (s2_is_inf_a) begin
                    result <= {s2_sign_a, 8'hFF, 23'b0};
                end else if (s2_is_inf_b) begin
                    result <= {s2_sign_b, 8'hFF, 23'b0};
                end else if (s2_sum == 0) begin
                    result <= 32'b0;  // explicit zero result
                end else begin
                    reg [7:0]  exp;
                    reg [23:0] frac;
                    reg [4:0]  shift;

                    exp = s2_exp_large;
                    frac = s2_sum[23:0];
                    shift = 0;

                    // Normalize
                    if (s2_sum[24]) begin
                        frac = s2_sum[24:1];
                        exp = exp + 1;
                    end else begin
                        while (frac[23] == 0 && exp > 0) begin
                            frac = frac << 1;
                            exp = exp - 1;
                            shift = shift + 1;
                        end
                    end

                    result <= {s2_result_sign, exp, frac[22:0]};
                end
            end
        end
    end

endmodule
