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

    // === Memory-mapped Registers ===
    reg [31:0] operand_a;
    reg [31:0] operand_b;
    reg [1:0]  control;
    reg [31:0] result;
    reg        busy;

    // === FSM States ===
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        WAIT  = 2'b10
    } fpu_state_t;

    fpu_state_t state;

    // === Input Control Logic ===
    wire [31:0] b_muxed = (control == 2'b11) ? {~operand_b[31], operand_b[30:0]} : operand_b;
    reg         valid_in;

    // === Pipelined Adder ===
    wire [31:0] add_result;
    wire        add_valid_out;

    fpu_add_pipelined add_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in && (control == 2'b01 || control == 2'b11)),
        .a(operand_a),
        .b(b_muxed),
        .valid_out(add_valid_out),
        .result(add_result)
    );

    // === Pipelined Multiplier ===
    wire [31:0] mul_result;
    wire        mul_valid_out;

    fpu_mult_pipelined mul_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in && (control == 2'b10)),
        .a(operand_a),
        .b(operand_b),
        .valid_out(mul_valid_out),
        .result(mul_result)
    );

    // === Write Logic ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            operand_a <= 0;
            operand_b <= 0;
            control   <= 0;
            valid_in  <= 0;
            state     <= IDLE;
            busy      <= 0;
            result    <= 0;
        end else begin
            valid_in <= 0;  // default

            case (state)
                IDLE: begin
                    busy <= 0;
                    if (data_write_n != 2'b11) begin
                        case (address)
                            6'h00: operand_a <= data_in;
                            6'h04: operand_b <= data_in;
                            6'h08: begin
                                control <= data_in[1:0];
                                if (data_in[1:0] != 2'b00) begin
                                    valid_in <= 1;
                                    busy     <= 1;
                                    state    <= WAIT;
                                end
                            end
                        endcase
                    end
                end

                WAIT: begin
                    if ((control == 2'b01 || control == 2'b11) && add_valid_out) begin
                        result <= add_result;
                        state  <= IDLE;
                    end else if (control == 2'b10 && mul_valid_out) begin
                        result <= mul_result;
                        state  <= IDLE;
                    end
                end
            endcase
        end
    end

    // === Read Logic ===
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
