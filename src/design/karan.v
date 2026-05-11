//=============================================================================
// alu_project — FIXED VERSION
// All bugs from verification corrected:
//
// Bug1 (CMD=7):   was accepting inp_valid==2'b01 (OPA valid) for an OPB op.
//                 Fixed to 2'b10 (OPB valid).
//
// Bug2 (default arith): was clearing outputs silently, no ERR.
//                 Fixed to set prev_err=1.
//
// Bug3 (CMD=9 invalid): was writing res directly (bypassing pipeline).
//                 Fixed to only set prev_err.
//
// Bug4 (CMD=3 OFLOW): width mismatch in borrow check.
//                 Fixed to 9-bit safe comparison.
//
// Bug5 (CMD=10 invalid): was writing stale temp_a*temp_b into prev_res on error.
//                 Fixed to only set prev_err.
//=============================================================================
`timescale 1ns/1ps

module alu_project #(parameter width = 8, cmd_width = 4)(
    input                       clk, rst, cin, ce, mode,
    input  [1:0]                inp_valid,
    input  [width-1:0]          opa, opb,
    input  [cmd_width-1:0]      cmd,
    output reg [2*width-1:0]    res,
    output reg                  oflow, cout, g, l, e, err
);

    reg [width-1:0]   temp_a, temp_b;
    reg [2*width-1:0] prev_res;
    reg               prev_err, prev_oflow, prev_cout, prev_g, prev_l, prev_e;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res   <= 0; oflow <= 0; cout <= 0;
            g     <= 0; l     <= 0; e    <= 0; err <= 0;
        end

        else if (ce) begin

            // ── Stage 2: push prev to outputs ────────────────────────────
            res   <= prev_res;
            err   <= prev_err;
            oflow <= prev_oflow;
            cout  <= prev_cout;
            g     <= prev_g;
            l     <= prev_l;
            e     <= prev_e;

            // ── Clear prev defaults for next cycle ───────────────────────
            prev_res   <= 0; prev_err   <= 0; prev_oflow <= 0;
            prev_cout  <= 0; prev_g     <= 0; prev_l     <= 0; prev_e <= 0;

            // ── Stage 1: compute into prev ───────────────────────────────
            if (mode) begin
                // ── ARITHMETIC MODE ──────────────────────────────────────
                case (cmd)

                    // CMD=0: ADD
                    0: begin
                        if (inp_valid == 2'b11) begin
                            prev_res  <= opa + opb;
                            prev_cout <= ({1'b0,opa} + {1'b0,opb}) >> width;
                        end else
                            prev_err <= 1;
                    end

                    // CMD=1: SUB
                    1: begin
                        if (inp_valid == 2'b11) begin
                            prev_res   <= opa - opb;
                            prev_oflow <= (opa < opb);
                        end else
                            prev_err <= 1;
                    end

                    // CMD=2: ADD + CIN
                    2: begin
                        if (inp_valid == 2'b11) begin
                            prev_res  <= opa + opb + cin;
                            prev_cout <= ({1'b0,opa} + {1'b0,opb} + cin) >> width;
                        end else
                            prev_err <= 1;
                    end

                    // CMD=3: SUB - CIN
                    // FIX Bug4: was  opa < {1'b0,opb}+cin  (width mismatch risk)
                    //           now  {1'b0,opa} < ({1'b0,opb}+cin)  (safe 9-bit)
                    3: begin
                        if (inp_valid == 2'b11) begin
                            prev_res   <= opa - opb - cin;
                            prev_oflow <= ({1'b0,opa} < ({1'b0,opb} + cin));
                        end else
                            prev_err <= 1;
                    end

                    // CMD=4: INC OPA
                    4: begin
                        if (inp_valid == 2'b11 || inp_valid == 2'b01)
                            prev_res <= opa + 1;
                        else
                            prev_err <= 1;
                    end

                    // CMD=5: DEC OPA
                    5: begin
                        if (inp_valid == 2'b11 || inp_valid == 2'b01)
                            prev_res <= opa - 1;
                        else
                            prev_err <= 1;
                    end

                    // CMD=6: INC OPB
                    6: begin
                        if (inp_valid == 2'b11 || inp_valid == 2'b10)
                            prev_res <= opb + 1;
                        else
                            prev_err <= 1;
                    end

                    // CMD=7: DEC OPB
                    // FIX Bug1: was inp_valid==2'b01 (OPA valid — wrong for OPB op)
                    //           now inp_valid==2'b10 (OPB valid — correct)
                    7: begin
                        if (inp_valid == 2'b11 || inp_valid == 2'b10)
                            prev_res <= opb - 1;
                        else
                            prev_err <= 1;
                    end

                    // CMD=8: COMPARE unsigned
                    8: begin
                        if (inp_valid == 2'b11) begin
                            if      (opa > opb) prev_g <= 1;
                            else if (opa < opb) prev_l <= 1;
                            else                prev_e <= 1;
                        end else
                            prev_err <= 1;
                    end

                    // CMD=9: MUL (OPA+1)*(OPB+1) — 2-cycle
                    // FIX Bug3: was writing  res <= temp_a*temp_b  directly on invalid
                    //           (bypasses pipeline, corrupts res immediately)
                    //           now only sets prev_err
                    9: begin
                        if (inp_valid == 2'b11) begin
                            temp_a   <= opa + 1;
                            temp_b   <= opb + 1;
                            prev_res <= temp_a * temp_b;
                        end else
                            prev_err <= 1;
                    end

                    // CMD=10: MUL2x (OPA<<1)*OPB — 2-cycle
                    // FIX Bug5: was writing  prev_res<=temp_a*temp_b  on invalid
                    //           (stale multiply result leaked on error)
                    //           now only sets prev_err
                    10: begin
                        if (inp_valid == 2'b11) begin
                            temp_a   <= opa << 1;
                            temp_b   <= opb;
                            prev_res <= temp_a * temp_b;
                        end else
                            prev_err <= 1;
                    end

                    // CMD=11: SIGNED ADD
                    11: begin
                        if (inp_valid == 2'b11) begin
                            if      ($signed(opa) > $signed(opb)) prev_g <= 1;
                            else if ($signed(opa) < $signed(opb)) prev_l <= 1;
                            else                                   prev_e <= 1;
                            prev_res   <= $signed(opa) + $signed(opb);
                            prev_oflow <= (opa[width-1] == opb[width-1]) &&
                                          ((((opa+opb) >> (width-1)) & 1'b1) != opa[width-1]);
                        end else
                            prev_err <= 1;
                    end

                    // CMD=12: SIGNED SUB
                    12: begin
                        if (inp_valid == 2'b11) begin
                            if      ($signed(opa) > $signed(opb)) prev_g <= 1;
                            else if ($signed(opa) < $signed(opb)) prev_l <= 1;
                            else                                   prev_e <= 1;
                            prev_res   <= $signed(opa) - $signed(opb);
                            prev_oflow <= (opa[width-1] != opb[width-1]) &&
                                          ((((opa-opb) >> (width-1)) & 1'b1) != opa[width-1]);
                        end else
                            prev_err <= 1;
                    end

                    // DEFAULT: unimplemented CMD (13,14,15)
                    // FIX Bug2: was silently clearing outputs — no ERR asserted
                    //           now correctly sets prev_err=1
                    default: begin
                        prev_err <= 1;
                        prev_res <= 0;
                    end

                endcase

            end else begin
                // ── LOGICAL MODE ─────────────────────────────────────────
                case (cmd)
                    0:  if (inp_valid==2'b11) prev_res<=opa&opb;    else prev_err<=1;
                    1:  if (inp_valid==2'b11) prev_res<=~(opa&opb); else prev_err<=1;
                    2:  if (inp_valid==2'b11) prev_res<=opa|opb;    else prev_err<=1;
                    3:  if (inp_valid==2'b11) prev_res<=~(opa|opb); else prev_err<=1;
                    4:  if (inp_valid==2'b11) prev_res<=opa^opb;    else prev_err<=1;
                    5:  if (inp_valid==2'b11) prev_res<=~(opa^opb); else prev_err<=1;

                    6:  if (inp_valid==2'b11||inp_valid==2'b01) prev_res<=~opa;   else prev_err<=1;
                    7:  if (inp_valid==2'b11||inp_valid==2'b10) prev_res<=~opb;   else prev_err<=1;
                    8:  if (inp_valid==2'b11||inp_valid==2'b01) prev_res<=opa>>1; else prev_err<=1;
                    9:  if (inp_valid==2'b11||inp_valid==2'b01) prev_res<=opa<<1; else prev_err<=1;
                    10: if (inp_valid==2'b11||inp_valid==2'b10) prev_res<=opb>>1; else prev_err<=1;
                    11: if (inp_valid==2'b11||inp_valid==2'b10) prev_res<=opb<<1; else prev_err<=1;

                    // CMD=12: ROL
                    12: begin
                        if (inp_valid==2'b11) begin
                            if (opb[7:4] != 0) prev_err <= 1;
                            case (opb[2:0])
                                0: prev_res <= opa;
                                1: prev_res <= {opa[width-2:0], opa[width-1]};
                                2: prev_res <= {opa[width-3:0], opa[width-1:width-2]};
                                3: prev_res <= {opa[width-4:0], opa[width-1:width-3]};
                                4: prev_res <= {opa[width-5:0], opa[width-1:width-4]};
                                5: prev_res <= {opa[width-6:0], opa[width-1:width-5]};
                                6: prev_res <= {opa[width-7:0], opa[width-1:width-6]};
                                7: prev_res <= {opa[width-8:0], opa[width-1:width-7]};
                            endcase
                        end else prev_err <= 1;
                    end

                    // CMD=13: ROR
                    13: begin
                        if (inp_valid==2'b11) begin
                            if (opb[7:4] != 0) prev_err <= 1;
                            case (opb[2:0])
                                0: prev_res <= opa;
                                1: prev_res <= {opa[0],   opa[width-1:1]};
                                2: prev_res <= {opa[1:0], opa[width-1:2]};
                                3: prev_res <= {opa[2:0], opa[width-1:3]};
                                4: prev_res <= {opa[3:0], opa[width-1:4]};
                                5: prev_res <= {opa[4:0], opa[width-1:5]};
                                6: prev_res <= {opa[5:0], opa[width-1:6]};
                                7: prev_res <= {opa[6:0], opa[width-1:7]};
                            endcase
                        end else prev_err <= 1;
                    end

                    // Default logical (CMD 14,15)
                    default: begin
                        prev_err <= 1;
                        prev_res <= 0;
                    end
                endcase
            end
        end
    end

endmodule

