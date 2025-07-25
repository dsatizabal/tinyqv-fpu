/*
 * Copyright (c) 2025 Diego Satizabal
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tqvp_dsatizabal_fpu (
    input         clk,
    input         rst_n,

    input  [7:0]  ui_in,
    output [7:0]  uo_out,

    input [5:0]   address,
    input [31:0]  data_in,
    input [1:0]   data_write_n,
    input [1:0]   data_read_n,
    output [31:0] data_out,
    output        data_ready,

    output        user_interrupt
);
    // Define memory-mapped registers
    reg [31:0] operand_a;
    reg [31:0] operand_b;
    reg [1:0]  control;
    reg [31:0] result;
    reg        busy;

    // Write logic
    always @(posedge clk) begin
        if (!rst_n) begin
            operand_a <= 0;
            operand_b <= 0;
            control   <= 0;
            busy      <= 0;
        end else begin
            if (data_write_n != 2'b11) begin
                case (address)
                    6'h00: operand_a <= data_in;
                    6'h04: operand_b <= data_in;
                    6'h08: control   <= data_in[1:0];
                endcase
            end

            // Start operation when control is written
            if (control != 0 && !busy) begin
                busy <= 1;
            end
        end
    end

    // Combinational core modules
    wire [31:0] add_result, mul_result;

    fpu_add add_inst (
        .a(operand_a),
        .b(operand_b),
        .result(add_result)
    );

    fpu_mult mult_inst (
        .a(operand_a),
        .b(operand_b),
        .result(mul_result)
    );

    // Compute result
    always @(posedge clk) begin
        if (!rst_n) begin
            result <= 0;
        end else if (busy) begin
            case (control)
                2'b01: result <= add_result;
                2'b10: result <= mul_result;
                default: result <= 32'h0;
            endcase
            busy <= 0;
            control <= 0;
        end
    end

    // Read logic
    assign data_out = (address == 6'h00) ? operand_a :
                      (address == 6'h04) ? operand_b :
                      (address == 6'h08) ? {30'b0, control} :
                      (address == 6'h0C) ? result :
                      (address == 6'h10) ? {31'b0, busy} :
                      32'h0;

    assign data_ready = 1;

    assign uo_out = 0;
    assign user_interrupt = 0;
    wire _unused = &{ui_in, data_read_n};

endmodule
