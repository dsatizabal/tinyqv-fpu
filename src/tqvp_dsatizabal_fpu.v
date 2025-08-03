`default_nettype none

module tqvp_dsatizabal_fpu (
    input         clk,
    input         rst_n,

    input  [7:0]  ui_in,
    output [7:0]  uo_out,

    input  [5:0]  address,
    input  [31:0] data_in,
    input  [1:0]  data_write_n,
    input  [1:0]  data_read_n,
    output [31:0] data_out,
    output        data_ready,

    output        user_interrupt
);

    // === Memory-mapped Registers ===
    reg [15:0] operand_a;
    reg [15:0] operand_b;
    reg [2:0]  operation;

    reg [15:0] result;
    reg        ready;

    reg        fpu_active;
    reg        req;
    wire       ack;

    // === FPU Operations ===
    typedef enum logic [2:0] {
        ADD     = 3'b000,
        SUB     = 3'b001,
        MULT    = 3'b010
    } fpu_operations_t;

    // === B muxing for SUB ===
    wire [15:0] b_muxed = (operation == SUB) ? {~operand_b[15], operand_b[14:0]} : operand_b;

    // === Result wires ===
    wire [15:0] adder_result;
    wire [15:0] mult_result;

    // === Module instances ===
    wire ack_add, ack_mul;

    async_fpu_adder add_inst (
        .a(operand_a),
        .b(b_muxed),
        .req_in(req && (operation == ADD || operation == SUB) && state == WAIT_ACK),
        .ack_out(ack_add),
        .result(adder_result)
    );

    async_fpu_mult mult_inst (
        .a(operand_a),
        .b(operand_b),
        .req_in(req && operation == MULT && state == WAIT_ACK),
        .ack_out(ack_mul),
        .result(mult_result)
    );

    assign ack = (operation == MULT) ? ack_mul : ack_add;

    // === FSM ===
    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        READ_B      = 2'b01,
        WAIT_ACK    = 2'b10
    } state_t;

    reg[1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            operand_a <= 0;
            operand_b <= 0;
            operation <= 0;
            result    <= 0;
            ready     <= 0;
            req       <= 0;
            fpu_active <= 0;
            state     <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (data_write_n != 2'b11 && address[1:0] == 2'b00) begin
                        operand_a   <= data_in[15:0];
                        operation   <= address[4:2];
                        state       <= READ_B;
                        fpu_active  <= 1;
                        ready       <= 1;
                    end
                end
                READ_B: begin
                    if (data_write_n != 2'b11 && address[1:0] == 2'b01) begin
                        operand_b <= data_in[15:0];
                        req       <= 1;
                        state     <= WAIT_ACK;
                    end
                end
                WAIT_ACK: begin
                    if (ack) begin
                        result      <= (operation == MULT) ? mult_result : adder_result;
                        ready       <= 1;
                        state       <= IDLE;
                        fpu_active  <= 0;
                    end
                end
            endcase
        end
    end

    // === Read Logic ===
    assign data_out = (address == 6'h00) ? {16'b0, operand_a} :
                      (address == 6'h04) ? {16'b0, operand_b} :
                      (address == 6'h08) ? {29'b0, operation} :
                      (address == 6'h0C) ? {16'b0, result} :
                      (address == 6'h10) ? {31'b0, fpu_active} :
                      32'h0;

    assign data_ready       = ready;
    assign uo_out           = 0;
    assign user_interrupt   = 0;

endmodule
