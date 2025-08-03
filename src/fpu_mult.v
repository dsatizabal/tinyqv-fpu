`timescale 1ns / 1ps
`default_nettype none

module async_fpu_mult (
    input  wire        req_in,
    output reg         ack_out,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] result,
    output reg         valid_out
);

    // Stage flags
    reg latched, decode_done, mult_done, norm_done, computed;

    // Input registers
    reg [15:0] reg_a, reg_b;

    // Decoded values
    reg sign_a, sign_b;
    reg [9:0] mant_a, mant_b;
    reg [10:0] frac_a, frac_b;
    reg is_nan_a, is_nan_b;
    reg is_inf_a, is_inf_b;
    reg is_zero_a, is_zero_b;

    // Intermediate results
    reg [21:0] product;
    reg [5:0] raw_exp;
    reg result_sign;
    reg is_nan;
    reg [9:0] norm_mant;
    reg [4:0] safe_exp;

    always @(*) begin
        // Default outputs
        ack_out   = 0;
        valid_out = 0;

        // LATCH stage
        if (req_in && !latched) begin
            reg_a = a;
            reg_b = b;
            latched = 1;
        end

        // DECODE stage
        if (latched && !decode_done) begin
            sign_a     = reg_a[15];
            mant_a     = reg_a[9:0];
            frac_a     = (reg_a[14:10] == 5'b0) ? {1'b0, reg_a[9:0]} : {1'b1, reg_a[9:0]};
            is_nan_a   = (reg_a[14:10] == 5'b11111) && (reg_a[9:0] != 0);
            is_inf_a   = (reg_a[14:10] == 5'b11111) && (reg_a[9:0] == 0);
            is_zero_a  = (reg_a[14:10] == 5'b0) && (reg_a[9:0] == 0);

            sign_b     = reg_b[15];
            mant_b     = reg_b[9:0];
            frac_b     = (reg_b[14:10] == 5'b0) ? {1'b0, reg_b[9:0]} : {1'b1, reg_b[9:0]};
            is_nan_b   = (reg_b[14:10] == 5'b11111) && (reg_b[9:0] != 0);
            is_inf_b   = (reg_b[14:10] == 5'b11111) && (reg_b[9:0] == 0);
            is_zero_b  = (reg_b[14:10] == 5'b0) && (reg_b[9:0] == 0);

            decode_done = 1;
        end

        // MULTIPLY stage
        if (decode_done && !mult_done) begin
            product = frac_a * frac_b;
            raw_exp = reg_a[14:10] + reg_b[14:10] - 5'd15;
            result_sign = sign_a ^ sign_b;
            is_nan = is_nan_a | is_nan_b | ((is_inf_a | is_inf_b) & (is_zero_a | is_zero_b));
            mult_done = 1;
        end

        // NORMALIZE stage
        if (mult_done && !norm_done) begin
            if (product[21]) begin
                // Overflow
                norm_mant = product[20:11];
                raw_exp   = raw_exp + 1;
            end else begin
                norm_mant = product[19:10];
            end
            norm_done = 1;
        end

        // PACK stage
        if (norm_done && !computed) begin
            if (is_nan) begin
                result = 16'h7E00; // Quiet NaN
            end else if (is_inf_a || is_inf_b) begin
                result = {result_sign, 5'b11111, 10'b0}; // Infinity
            end else if (is_zero_a || is_zero_b) begin
                result = {result_sign, 15'b0}; // Zero
            end else begin
                // Clamp exponent (saturate if too high)
                safe_exp = (raw_exp[5] == 1'b1) ? 5'd0 : raw_exp[4:0];
                result = {result_sign, safe_exp, norm_mant};
            end
            computed = 1;
        end

        // Output ready
        if (computed) begin
            ack_out   = 1;
            valid_out = 1;
        end

        // Reset state when req_in goes low
        if (!req_in) begin
            result       = 0;
            latched      = 0;
            decode_done  = 0;
            mult_done    = 0;
            norm_done    = 0;
            computed     = 0;
            ack_out      = 0;
            valid_out    = 0;
        end
    end

endmodule
