//=============================================================================
// Reference Model for alu.v
// Written from spec — mirrors the exact pipeline and behaviour of alu.v
//
// Architecture notes:
//  - Inputs registered on CE rising edge (opa_d, opb_d, cmd_d, inp_valid_d, cin_d)
//  - Outputs written DIRECTLY in same CE cycle using registered inputs
//  - CE=0 → RES cleared to 0 (not held like Karan.v)
//  - RST async → all outputs 0
//  - CMD=9,10 use cycle_cnt: cnt=1 loads operands (RES=X), cnt=2 computes result
//  - CMD=4,5 accept ONLY 2'b01  (strict — not 2'b11)
//  - CMD=6,7 accept ONLY 2'b10  (strict — not 2'b11)
//  - Outputs cleared each CE cycle before case executes
//=============================================================================
`timescale 1ns/1ps

module alu_ref_model #(
    parameter DATA_WIDTH = 8,
    parameter CMD_WIDTH  = 4
)(
    input                          CLK,
    input                          RST,
    input                          MODE,
    input                          CE,
    input  [1:0]                   INP_VALID,
    input  [CMD_WIDTH-1:0]         CMD,
    input  [DATA_WIDTH-1:0]        OPA,
    input  [DATA_WIDTH-1:0]        OPB,
    input                          CIN,
    output reg [(2*DATA_WIDTH)-1:0] RES,
    output reg                     OFLOW,
    output reg                     COUT,
    output reg                     G,
    output reg                     L,
    output reg                     E,
    output reg                     ERR
);

    // ── Registered inputs (sampled on CE) ────────────────────────────────────
    reg [CMD_WIDTH-1:0]  cmd_d;
    reg [1:0]            inp_valid_d;
    reg [DATA_WIDTH-1:0] opa_d, opb_d;
    reg                  cin_d;

    // ── Multi-cycle multiply registers ───────────────────────────────────────
    reg [1:0]            cycle_cnt;
    reg [DATA_WIDTH-1:0] mul_op_a, mul_op_b;

    // ── Signed overflow detection (combinational, uses registered inputs) ─────
    wire [DATA_WIDTH:0]  signed_sum_ext;
    assign signed_sum_ext = $signed(opa_d) + $signed(opb_d);

    // ── cycle_cnt: separate always block, no RST (matches alu.v exactly) ─────
    always @(posedge CLK) begin
        if (MODE && (CMD == 4'd9 || CMD == 4'd10)) begin
            if (cycle_cnt < 2)
                cycle_cnt <= cycle_cnt + 1'b1;
            else
                cycle_cnt <= 1;
        end else begin
            cycle_cnt <= 0;
        end
    end

    // ── Main always block ─────────────────────────────────────────────────────
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            RES   <= 0; OFLOW <= 0; COUT <= 0;
            G     <= 0; L     <= 0; E    <= 0; ERR <= 0;
        end

        else if (CE) begin
            // ── Register inputs ───────────────────────────────────────────
            inp_valid_d <= INP_VALID;
            opa_d       <= OPA;
            opb_d       <= OPB;
            cmd_d       <= CMD;
            cin_d       <= CIN;

            // ── Clear flags every CE cycle (outputs updated in case below) 
            OFLOW <= 0; COUT <= 0;
            G     <= 0; L    <= 0; E <= 0; ERR <= 0;

            // ── ARITHMETIC MODE ───────────────────────────────────────────
            if (MODE) begin
                case (cmd_d)

                    // CMD=0: ADD → COUT + RES[7:0]
                    4'd0: begin
                        if (inp_valid_d == 2'b11)
                            {COUT, RES[DATA_WIDTH-1:0]} <= opa_d + opb_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=1: SUB → OFLOW if borrow
                    4'd1: begin
                        if (inp_valid_d == 2'b11) begin
                            OFLOW <= (opa_d < opb_d);
                            RES[DATA_WIDTH-1:0] <= opa_d - opb_d;
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=2: ADD + CIN → COUT + RES[7:0]
                    4'd2: begin
                        if (inp_valid_d == 2'b11)
                            {COUT, RES[DATA_WIDTH-1:0]} <= opa_d + opb_d + cin_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=3: SUB - CIN → no OFLOW (spec doesn't set it for CMD=3)
                    4'd3: begin
                        if (inp_valid_d == 2'b11)
                            RES[DATA_WIDTH-1:0] <= opa_d - opb_d - cin_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=4: INC OPA — ONLY 2'b01 valid (strict)
                    4'd4: begin
                        if (inp_valid_d == 2'b01)
                            RES[DATA_WIDTH-1:0] <= opa_d + 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=5: DEC OPA — ONLY 2'b01 valid (strict)
                    4'd5: begin
                        if (inp_valid_d == 2'b01)
                            RES[DATA_WIDTH-1:0] <= opa_d - 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=6: INC OPB — ONLY 2'b10 valid (strict)
                    4'd6: begin
                        if (inp_valid_d == 2'b10)
                            RES[DATA_WIDTH-1:0] <= opb_d + 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=7: DEC OPB — ONLY 2'b10 valid (strict)
                    4'd7: begin
                        if (inp_valid_d == 2'b10)
                            RES[DATA_WIDTH-1:0] <= opb_d - 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=8: COMPARE unsigned → G / L / E flags
                    4'd8: begin
                        if (inp_valid_d == 2'b11) begin
                            G <= (opa_d > opb_d);
                            E <= (opa_d == opb_d);
                            L <= (opa_d < opb_d);
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=9: MUL (OPA+1)*(OPB+1) — 2-cycle
                    //   cycle_cnt=1: load mul_op_a/b, RES=X (indeterminate)
                    //   cycle_cnt=2: RES = mul_op_a * mul_op_b (valid result)
                    4'd9: begin
                        if (inp_valid_d == 2'b11) begin
                            if (cycle_cnt == 2'd1) begin
                                mul_op_a <= opa_d + 1;
                                mul_op_b <= opb_d + 1;
                                RES      <= 'bx;
                            end else if (cycle_cnt == 2'd2) begin
                                RES <= mul_op_a * mul_op_b;
                            end else begin
                                RES <= RES;   // hold until cnt starts
                            end
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=10: MUL2x (OPA<<1)*OPB — 2-cycle
                    //   cycle_cnt=1: load mul_op_a (OPA<<1), RES=X
                    //   cycle_cnt=2: RES = mul_op_a * opb_d
                    4'd10: begin
                        if (inp_valid_d == 2'b11) begin
                            if (cycle_cnt == 2'd1) begin
                                mul_op_a <= opa_d << 1;
                                RES      <= 'bx;
                            end else if (cycle_cnt == 2'd2) begin
                                RES <= mul_op_a * opb_d;
                            end else begin
                                RES <= RES;
                            end
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=11: SIGNED ADD with overflow detection
                    //   signed_sum_ext is combinational: $signed(opa_d)+$signed(opb_d)
                    //   OFLOW: same sign inputs, result sign differs
                    4'd11: begin
                        if (inp_valid_d == 2'b11) begin
                            RES   <= $signed(opa_d) + $signed(opb_d);
                            OFLOW <= (opa_d[DATA_WIDTH-1] == opb_d[DATA_WIDTH-1]) &&
                                     (signed_sum_ext[DATA_WIDTH] != opa_d[DATA_WIDTH-1]);
                            G <= ($signed(opa_d) > $signed(opb_d));
                            E <= ($signed(opa_d) == $signed(opb_d));
                            L <= ($signed(opa_d) < $signed(opb_d));
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=12: SIGNED SUB
                    //   NOTE: OFLOW uses signed_sum_ext (opa_d+opb_d) not opa_d-opb_d
                    //   This matches alu.v exactly — signed_sum_ext is always add
                    4'd12: begin
                        if (inp_valid_d == 2'b11) begin
                            RES   <= $signed(opa_d) - $signed(opb_d);
                            OFLOW <= (opa_d[DATA_WIDTH-1] != opb_d[DATA_WIDTH-1]) &&
                                     (signed_sum_ext[DATA_WIDTH] != opa_d[DATA_WIDTH-1]);
                            G <= ($signed(opa_d) > $signed(opb_d));
                            E <= ($signed(opa_d) == $signed(opb_d));
                            L <= ($signed(opa_d) < $signed(opb_d));
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // Default: unimplemented CMD → ERR
                    default: begin ERR <= 1; RES <= 0; end

                endcase

            end else begin
                // ── LOGICAL MODE ──────────────────────────────────────────
                case (cmd_d)

                    // CMD=0: AND
                    4'd0: begin
                        if (inp_valid_d == 2'b11) RES <= opa_d & opb_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=1: NAND
                    4'd1: begin
                        if (inp_valid_d == 2'b11) RES <= ~(opa_d & opb_d);
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=2: OR
                    4'd2: begin
                        if (inp_valid_d == 2'b11) RES <= opa_d | opb_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=3: NOR
                    4'd3: begin
                        if (inp_valid_d == 2'b11) RES <= ~(opa_d | opb_d);
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=4: XOR
                    4'd4: begin
                        if (inp_valid_d == 2'b11) RES <= opa_d ^ opb_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=5: XNOR
                    4'd5: begin
                        if (inp_valid_d == 2'b11) RES <= ~(opa_d ^ opb_d);
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=6: NOT_A — ONLY 2'b01
                    4'd6: begin
                        if (inp_valid_d == 2'b01) RES <= ~opa_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=7: NOT_B — ONLY 2'b10
                    4'd7: begin
                        if (inp_valid_d == 2'b10) RES <= ~opb_d;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=8: SHR_A — ONLY 2'b01
                    4'd8: begin
                        if (inp_valid_d == 2'b01) RES <= opa_d >> 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=9: SHL_A — ONLY 2'b01
                    4'd9: begin
                        if (inp_valid_d == 2'b01) RES <= opa_d << 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=10: SHR_B — ONLY 2'b10
                    4'd10: begin
                        if (inp_valid_d == 2'b10) RES <= opb_d >> 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=11: SHL_B — ONLY 2'b10
                    4'd11: begin
                        if (inp_valid_d == 2'b10) RES <= opb_d << 1;
                        else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=12: ROL — rotate OPA left by OPB[2:0]
                    //   OPB[DATA_WIDTH-1:4] != 0 → ERR=1 (invalid shift amount)
                    4'd12: begin
                        if (inp_valid_d == 2'b11) begin
                            RES[DATA_WIDTH-1:0] <=
                                (opa_d << (opb_d[$clog2(DATA_WIDTH)-1:0])) |
                                (opa_d >> (DATA_WIDTH - opb_d[$clog2(DATA_WIDTH)-1:0]));
                            if (opb_d[DATA_WIDTH-1:4] != 0)
                                ERR <= 1;
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // CMD=13: ROR — rotate OPA right by OPB[2:0]
                    4'd13: begin
                        if (inp_valid_d == 2'b11) begin
                            RES[DATA_WIDTH-1:0] <=
                                (opa_d >> (opb_d[$clog2(DATA_WIDTH)-1:0])) |
                                (opa_d << (DATA_WIDTH - opb_d[$clog2(DATA_WIDTH)-1:0]));
                            if (opb_d[DATA_WIDTH-1:4] != 0)
                                ERR <= 1;
                        end else begin ERR <= 1; RES <= 0; end
                    end

                    // Default: unimplemented CMD → ERR
                    default: begin ERR <= 1; RES <= 0; end

                endcase
            end
        end

        else begin
            // CE=0: RES cleared to 0 (matches alu.v behaviour)
            RES <= 0;
        end
    end

endmodule

