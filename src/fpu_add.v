`timescale 1ns / 1ps
`default_nettype none

module fpu_add_pipelined (
    input wire clk,
    input wire rst_n,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire valid_in,
    output reg [31:0] result,
    output reg valid_out
);

    // Stage 1
    reg [15:0] s1_a, s1_b;
    reg        s1_sign_a, s1_sign_b;
    reg [4:0]  s1_exp_a, s1_exp_b;
    reg [10:0] s1_frac_a, s1_frac_b;
    reg        s1_is_nan_a, s1_is_nan_b;
    reg        s1_is_inf_a, s1_is_inf_b;
    reg        s1_valid;

    // Stage 2
    reg [10:0] s2_frac_a, s2_frac_b;
    reg [4:0]  s2_exp_a, s2_exp_b;
    reg        s2_sign_a, s2_sign_b;
    reg        s2_valid;
    reg        s2_is_nan_a, s2_is_nan_b;
    reg        s2_is_inf_a, s2_is_inf_b;
    reg        s2_is_conflicting_inf;
    reg [15:0] s2_nan_result;

    // Stage 3
    reg [11:0] s3_sum;
    reg [4:0]  s3_exp;
    reg        s3_result_sign;
    reg        s3_valid;
    reg [15:0] s3_nan_result;
    reg        s3_is_nan;
    reg        s3_is_conflicting_inf;
    reg        s3_is_inf_a, s3_is_inf_b;
    reg        s3_sign_a, s3_sign_b;

    // Stage 4
    reg [10:0] s4_frac;
    reg [4:0]  s4_exp;
    reg        s4_result_sign;
    reg        s4_valid;
    reg [15:0] s4_nan_result;
    reg        s4_is_nan;
    reg        s4_is_conflicting_inf;
    reg        s4_is_inf_a, s4_is_inf_b;
    reg        s4_sign_a, s4_sign_b;

    // Pipeline stage 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 0;
        end else begin
            s1_a <= a[15:0];
            s1_b <= b[15:0];
            s1_sign_a <= a[15];
            s1_sign_b <= b[15];
            s1_exp_a <= a[14:10];
            s1_exp_b <= b[14:10];
            s1_frac_a <= {1'b1, a[9:0]};
            s1_frac_b <= {1'b1, b[9:0]};
            s1_is_nan_a <= (&a[14:10]) && (|a[9:0]);
            s1_is_nan_b <= (&b[14:10]) && (|b[9:0]);
            s1_is_inf_a <= (&a[14:10]) && !(|a[9:0]);
            s1_is_inf_b <= (&b[14:10]) && !(|b[9:0]);
            s1_valid <= valid_in;
        end
    end

    // Pipeline stage 2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 0;
        end else begin
            s2_valid <= s1_valid;
            s2_sign_a <= s1_sign_a;
            s2_sign_b <= s1_sign_b;
            s2_exp_a <= s1_exp_a;
            s2_exp_b <= s1_exp_b;
            s2_is_nan_a <= s1_is_nan_a;
            s2_is_nan_b <= s1_is_nan_b;
            s2_is_inf_a <= s1_is_inf_a;
            s2_is_inf_b <= s1_is_inf_b;
            s2_is_conflicting_inf <= s1_is_inf_a && s1_is_inf_b && (s1_sign_a != s1_sign_b);
            s2_nan_result <= {1'b0, 5'b11111, 10'b1};  // default NaN

            if (s1_exp_a > s1_exp_b) begin
                s2_exp_a <= s1_exp_a;
                s2_exp_b <= s1_exp_a;
                s2_frac_a <= s1_frac_a;
                s2_frac_b <= s1_frac_b >> (s1_exp_a - s1_exp_b);
            end else begin
                s2_exp_a <= s1_exp_b;
                s2_exp_b <= s1_exp_b;
                s2_frac_a <= s1_frac_a >> (s1_exp_b - s1_exp_a);
                s2_frac_b <= s1_frac_b;
            end
        end
    end

    // Pipeline stage 3
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid <= 0;
        end else begin
            s3_valid <= s2_valid;
            s3_nan_result <= s2_nan_result;
            s3_is_nan <= s2_is_nan_a || s2_is_nan_b;
            s3_is_conflicting_inf <= s2_is_conflicting_inf;
            s3_is_inf_a <= s2_is_inf_a;
            s3_is_inf_b <= s2_is_inf_b;
            s3_sign_a <= s2_sign_a;
            s3_sign_b <= s2_sign_b;

            if (s2_sign_a == s2_sign_b) begin
                s3_sum <= s2_frac_a + s2_frac_b;
                s3_result_sign <= s2_sign_a;
            end else if (s2_frac_a >= s2_frac_b) begin
                s3_sum <= s2_frac_a - s2_frac_b;
                s3_result_sign <= s2_sign_a;
            end else begin
                s3_sum <= s2_frac_b - s2_frac_a;
                s3_result_sign <= s2_sign_b;
            end

            s3_exp <= s2_exp_a;
        end
    end

    // Pipeline stage 4
    integer i;
    reg [4:0]  temp_exp;
    reg [10:0] temp_frac;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid <= 0;
        end else begin
            s4_valid <= s3_valid;
            s4_nan_result <= s3_nan_result;
            s4_is_nan <= s3_is_nan;
            s4_is_conflicting_inf <= s3_is_conflicting_inf;
            s4_is_inf_a <= s3_is_inf_a;
            s4_is_inf_b <= s3_is_inf_b;
            s4_sign_a <= s3_sign_a;
            s4_sign_b <= s3_sign_b;

            if (s3_sum == 0) begin
                s4_exp         <= 0;
                s4_frac        <= 0;
                s4_result_sign <= 0;
            end else if (s3_sum[11]) begin
                s4_frac        <= s3_sum[11:1];
                s4_exp         <= s3_exp + 1;
                s4_result_sign <= s3_result_sign;
            end else begin
                temp_frac = s3_sum[10:0];
                temp_exp  = s3_exp;
                s4_result_sign <= s3_result_sign;

                for (i = 10; i >= 0; i = i - 1) begin
                    if (temp_frac[10]) begin
                        i = -1;
                    end else begin
                        temp_frac = temp_frac << 1;
                        temp_exp  = temp_exp - 1;
                    end
                end

                s4_frac <= temp_frac;
                s4_exp  <= temp_exp;
            end
        end
    end

    // Pipeline stage 5 (final output)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            result <= 0;
        end else begin
            valid_out <= s4_valid;
            if (s4_is_nan || s4_is_conflicting_inf) begin
                result <= {16'b0, s4_nan_result};
            end else if (s4_is_inf_a && s4_is_inf_b && s4_sign_a == s4_sign_b) begin
                result <= {16'b0, {s4_sign_a, 5'b11111, 10'b0}};
            end else if (s4_is_inf_a && !s4_is_inf_b) begin
                result <= {16'b0, {s4_sign_a, 5'b11111, 10'b0}};
            end else if (!s4_is_inf_a && s4_is_inf_b) begin
                result <= {16'b0, {s4_sign_b, 5'b11111, 10'b0}};
            end else begin
                result <= {16'b0, {s4_result_sign, s4_exp, s4_frac[9:0]}};
            end
        end
    end

endmodule
