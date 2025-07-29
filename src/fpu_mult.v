/*
 * IEEE 754 Half-Precision (16-bit) Floating Point Multiplier
 * 5-stage pipelined version for reduced area
 * Maintains 32-bit interface for compatibility
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

    // === Stage 1 ===
    reg        s1_valid;
    reg        s1_sign_a, s1_sign_b;
    reg [4:0]  s1_exp_a, s1_exp_b;
    reg [9:0]  s1_mant_a, s1_mant_b;
    reg [10:0] s1_frac_a, s1_frac_b;
    reg        s1_is_nan_a, s1_is_nan_b;
    reg        s1_is_inf_a, s1_is_inf_b;
    reg        s1_is_zero_a, s1_is_zero_b;

    wire [15:0] in_a = a[15:0];
    wire [15:0] in_b = b[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) s1_valid <= 1'b0;
        else begin
            s1_valid   <= valid_in;
            s1_sign_a  <= in_a[15];
            s1_sign_b  <= in_b[15];
            s1_exp_a   <= in_a[14:10];
            s1_exp_b   <= in_b[14:10];
            s1_mant_a  <= in_a[9:0];
            s1_mant_b  <= in_b[9:0];
            s1_frac_a  <= (in_a[14:10] == 5'b0) ? {1'b0, in_a[9:0]} : {1'b1, in_a[9:0]};
            s1_frac_b  <= (in_b[14:10] == 5'b0) ? {1'b0, in_b[9:0]} : {1'b1, in_b[9:0]};
            s1_is_nan_a  <= (in_a[14:10] == 5'b11111) && (in_a[9:0] != 0);
            s1_is_nan_b  <= (in_b[14:10] == 5'b11111) && (in_b[9:0] != 0);
            s1_is_inf_a  <= (in_a[14:10] == 5'b11111) && (in_a[9:0] == 0);
            s1_is_inf_b  <= (in_b[14:10] == 5'b11111) && (in_b[9:0] == 0);
            s1_is_zero_a <= (in_a[14:10] == 5'b0) && (in_a[9:0] == 0);
            s1_is_zero_b <= (in_b[14:10] == 5'b0) && (in_b[9:0] == 0);
        end
    end

    // === Stage 2 ===
    reg        s2_valid;
    reg [21:0] s2_product;
    reg [5:0]  s2_raw_exp;
    reg        s2_result_sign;
    reg        s2_is_nan;
    reg        s2_is_inf_a, s2_is_inf_b;
    reg        s2_is_zero_a, s2_is_zero_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) s2_valid <= 1'b0;
        else begin
            s2_valid        <= s1_valid;
            s2_result_sign  <= s1_sign_a ^ s1_sign_b;
            s2_product      <= s1_frac_a * s1_frac_b;
            s2_raw_exp      <= s1_exp_a + s1_exp_b - 5'd15;
            s2_is_nan       <= s1_is_nan_a | s1_is_nan_b | ((s1_is_inf_a | s1_is_inf_b) & (s1_is_zero_a | s1_is_zero_b));
            s2_is_inf_a     <= s1_is_inf_a;
            s2_is_inf_b     <= s1_is_inf_b;
            s2_is_zero_a    <= s1_is_zero_a;
            s2_is_zero_b    <= s1_is_zero_b;
        end
    end

    // === Stage 3 ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= s2_valid;
            if (s2_valid) begin
                if (s2_is_nan) begin
                    result <= {16'b0, 16'h7E00};
                end else if (s2_is_inf_a | s2_is_inf_b) begin
                    result <= {16'b0, {s2_result_sign, 5'b11111, 10'b0}};
                end else if (s2_is_zero_a | s2_is_zero_b) begin
                    result <= {16'b0, {s2_result_sign, 15'b0}};
                end else begin
                    reg [9:0] norm_mant;
                    reg [4:0] norm_exp;

                    if (s2_product[21]) begin
                        norm_mant = s2_product[20:11];
                        norm_exp  = s2_raw_exp + 1;
                    end else begin
                        norm_mant = s2_product[19:10];
                        norm_exp  = s2_raw_exp;
                    end

                    result <= {16'b0, {s2_result_sign, norm_exp, norm_mant}};
                end
            end
        end
    end

endmodule
