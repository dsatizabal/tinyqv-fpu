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

    localparam IDLE       = 3'd0;
    localparam DECODE     = 3'd1;
    localparam ALIGN      = 3'd2;
    localparam CALCULATE  = 3'd3;
    localparam NORMALIZE  = 3'd4;
    localparam PACK       = 3'd5;

    reg [2:0] state;

    reg [15:0] reg_a, reg_b;

    reg sign_a, sign_b;
    reg [4:0] exp_a, exp_b, exp_max;
    reg [10:0] frac_a, frac_b;
    reg is_nan_a, is_nan_b;
    reg is_inf_a, is_inf_b;

    reg [10:0] aligned_a, aligned_b;
    reg [4:0] shift_amt;

    reg [11:0] sum;
    reg result_sign;

    reg [10:0] norm_frac;
    reg [4:0] norm_exp;

    reg is_conflicting_inf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_out <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        reg_a <= a[15:0];
                        reg_b <= b[15:0];
                        state <= DECODE;
                    end
                end

                DECODE: begin
                    sign_a <= reg_a[15];
                    exp_a <= reg_a[14:10];
                    frac_a <= (reg_a[14:10] != 0) ? {1'b1, reg_a[9:0]} : {1'b0, reg_a[9:0]};
                    is_nan_a <= (&reg_a[14:10]) && (|reg_a[9:0]);
                    is_inf_a <= (&reg_a[14:10]) && !(|reg_a[9:0]);

                    sign_b <= reg_b[15];
                    exp_b <= reg_b[14:10];
                    frac_b <= (reg_b[14:10] != 0) ? {1'b1, reg_b[9:0]} : {1'b0, reg_b[9:0]};
                    is_nan_b <= (&reg_b[14:10]) && (|reg_b[9:0]);
                    is_inf_b <= (&reg_b[14:10]) && !(|reg_b[9:0]);

                    state <= ALIGN;
                end

                ALIGN: begin
                    is_conflicting_inf <= is_inf_a && is_inf_b && (sign_a != sign_b);
                    if (exp_a > exp_b) begin
                        shift_amt <= exp_a - exp_b;
                        exp_max <= exp_a;
                        aligned_a <= frac_a;
                        aligned_b <= frac_b >> (exp_a - exp_b);
                    end else begin
                        shift_amt <= exp_b - exp_a;
                        exp_max <= exp_b;
                        aligned_a <= frac_a >> (exp_b - exp_a);
                        aligned_b <= frac_b;
                    end
                    state <= CALCULATE;
                end

                CALCULATE: begin
                    if (sign_a == sign_b) begin
                        // Same signs: add magnitudes
                        sum <= {1'b0, aligned_a} + {1'b0, aligned_b};
                        result_sign <= sign_a;
                    end else begin
                        // Different signs: subtract smaller from larger
                        if (aligned_a > aligned_b) begin
                            sum <= {1'b0, aligned_a} - {1'b0, aligned_b};
                            result_sign <= sign_a;
                        end else if (aligned_b > aligned_a) begin
                            sum <= {1'b0, aligned_b} - {1'b0, aligned_a};
                            result_sign <= sign_b;
                        end else begin
                            // Equal magnitudes: result is zero
                            sum <= 0;
                            result_sign <= 0;
                        end
                    end
                    norm_exp <= exp_max;
                    state <= NORMALIZE;
                end

                NORMALIZE: begin
                    if (sum == 0) begin
                        norm_frac <= 0;
                        norm_exp <= 0;
                        result_sign <= 0;
                    end else begin
                        if (sum[11]) begin
                            // Overflow case - shift right by 1
                            norm_frac <= sum[11:1];
                            norm_exp <= norm_exp + 1;
                        end else begin
                            // Normal case - shift left until MSB is 1
                            norm_frac <= sum[10:0];
                            if (!sum[10]) begin
                                norm_frac <= sum[9:0] << 1;
                                norm_exp <= norm_exp - 1;
                            end
                        end
                    end
                    state <= PACK;
                end

                PACK: begin
                    valid_out <= 1;
                    if (is_nan_a || is_nan_b || is_conflicting_inf) begin
                        result <= {16'b0, 1'b0, 5'b11111, 10'b1}; // NaN
                    end else if (is_inf_a && is_inf_b && sign_a == sign_b) begin
                        result <= {16'b0, sign_a, 5'b11111, 10'b0}; // Infinity with same sign
                    end else if (is_inf_a) begin
                        result <= {16'b0, sign_a, 5'b11111, 10'b0}; // A is infinity
                    end else if (is_inf_b) begin
                        result <= {16'b0, sign_b, 5'b11111, 10'b0}; // B is infinity
                    end else begin
                        // Pack normal/denormal result
                        result <= {16'b0, result_sign, norm_exp, norm_frac[9:0]};
                    end
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule