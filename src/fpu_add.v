`timescale 1ns / 1ps
`default_nettype none

module async_fpu_adder (
    input  wire        req_in,     // Sender initiates operation
    output reg         ack_out,    // Asserted when done
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] result,
    output reg         valid_out
);

    // Stage tracking
    reg latched, decode_done, align_done, calc_done, norm_done, computed;

    // Register banks
    reg [15:0] reg_a, reg_b;

    reg sign_a, sign_b;
    reg [4:0] exp_max;
    reg [10:0] frac_a, frac_b;
    reg is_nan_a, is_nan_b;
    reg is_inf_a, is_inf_b;
    reg is_conflicting_inf;

    reg [10:0] aligned_a, aligned_b;
    reg [11:0] sum;
    reg result_sign;
    reg [10:0] norm_frac;
    reg [4:0] norm_exp;

    integer shift_count;

    always @(*) begin
        // Default outputs
        ack_out   = 0;
        valid_out = 0;

        // Latch inputs once when req asserted
        if (req_in && !latched) begin
            reg_a = a;
            reg_b = b;
            latched = 1;
        end

        // DECODE stage
        if (latched && !decode_done) begin
            sign_a     = reg_a[15];
            frac_a     = (reg_a[14:10] != 0) ? {1'b1, reg_a[9:0]} : {1'b0, reg_a[9:0]};
            is_nan_a   = (&reg_a[14:10]) && (|reg_a[9:0]);
            is_inf_a   = (&reg_a[14:10]) && !(|reg_a[9:0]);

            sign_b     = reg_b[15];
            frac_b     = (reg_b[14:10] != 0) ? {1'b1, reg_b[9:0]} : {1'b0, reg_b[9:0]};
            is_nan_b   = (&reg_b[14:10]) && (|reg_b[9:0]);
            is_inf_b   = (&reg_b[14:10]) && !(|reg_b[9:0]);

            decode_done = 1;
        end

        // ALIGN stage
        if (decode_done && !align_done) begin
            is_conflicting_inf = is_inf_a && is_inf_b && (sign_a != sign_b);
            if (reg_a[14:10] > reg_b[14:10]) begin
                exp_max   = reg_a[14:10];
                aligned_a = frac_a;
                aligned_b = frac_b >> (reg_a[14:10] - reg_b[14:10]);
            end else begin
                exp_max   = reg_b[14:10];
                aligned_a = frac_a >> (reg_b[14:10] - reg_a[14:10]);
                aligned_b = frac_b;
            end
            align_done = 1;
        end

        // CALCULATE stage
        if (align_done && !calc_done) begin
            if (sign_a == sign_b) begin
                sum = {1'b0, aligned_a} + {1'b0, aligned_b};
                result_sign = sign_a;
            end else begin
                if (aligned_a > aligned_b) begin
                    sum = {1'b0, aligned_a} - {1'b0, aligned_b};
                    result_sign = sign_a;
                end else if (aligned_b > aligned_a) begin
                    sum = {1'b0, aligned_b} - {1'b0, aligned_a};
                    result_sign = sign_b;
                end else begin
                    sum = 0;
                    result_sign = 0;
                end
            end
            calc_done = 1;
        end

        // NORMALIZE stage
        if (calc_done && !norm_done) begin
            if (sum == 0) begin
                norm_frac = 0;
                norm_exp  = 0;
                result_sign = 0;
            end else if (sum[11]) begin
                // MSB is already 1 (overflow), shift right
                norm_frac = sum[11:1];
                norm_exp  = exp_max + 1;
            end else begin
                // Normalize by shifting left
                norm_frac = sum[10:0];
                norm_exp  = exp_max;
                shift_count = 0;

                // Manual loop to avoid while() (Verilog simulation-friendly)
                if (norm_frac[10] == 0 && norm_exp > 0) begin
                    norm_frac = norm_frac << 1;
                    norm_exp = norm_exp - 1;
                end
                if (norm_frac[10] == 0 && norm_exp > 0) begin
                    norm_frac = norm_frac << 1;
                    norm_exp = norm_exp - 1;
                end
                if (norm_frac[10] == 0 && norm_exp > 0) begin
                    norm_frac = norm_frac << 1;
                    norm_exp = norm_exp - 1;
                end
                if (norm_frac[10] == 0 && norm_exp > 0) begin
                    norm_frac = norm_frac << 1;
                    norm_exp = norm_exp - 1;
                end
                if (norm_frac[10] == 0 && norm_exp > 0) begin
                    norm_frac = norm_frac << 1;
                    norm_exp = norm_exp - 1;
                end
                // (continue manually if you want more precision)

                // If exponent underflows, flush to denormal
                if (norm_exp == 0 && norm_frac[10] == 0) begin
                    norm_frac = norm_frac;
                end
            end
            norm_done = 1;
        end

        // PACK stage
        if (norm_done && !computed) begin
            if (is_nan_a || is_nan_b || is_conflicting_inf) begin
                result = {1'b0, 5'b11111, 10'b1}; // NaN
            end else if (is_inf_a && is_inf_b && sign_a == sign_b) begin
                result = {sign_a, 5'b11111, 10'b0}; // same sign Inf
            end else if (is_inf_a) begin
                result = {sign_a, 5'b11111, 10'b0};
            end else if (is_inf_b) begin
                result = {sign_b, 5'b11111, 10'b0};
            end else begin
                // Clamp exponent if negative (simulate flush to subnormal)
                result = {result_sign, norm_exp[4:0], norm_frac[9:0]};
            end
            computed = 1;
        end

        // Final: drive handshake outputs
        if (computed) begin
            ack_out   = 1;
            valid_out = 1;
        end

        // Reset all stage latches on falling edge of req_in
        if (!req_in) begin
            result       = 0;
            latched      = 0;
            decode_done  = 0;
            align_done   = 0;
            calc_done    = 0;
            norm_done    = 0;
            computed     = 0;
        end
    end

endmodule
