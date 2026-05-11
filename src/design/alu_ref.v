//=============================================================================
// ALU Reference Model — written from SPEC (aluext_code.txt)
// Same pipeline as Karan.v (prev_* → outputs next cycle)
// Bugs in Karan.v are NOT replicated here — this is the golden correct version
//=============================================================================
`timescale 1ns/1ps

module alu_ref_model #(parameter WIDTH = 8, CMD_WIDTH = 4)(
    input                      clk, rst, cin, ce, mode,
    input  [1:0]               inp_valid,
    input  [WIDTH-1:0]         opa, opb,
    input  [CMD_WIDTH-1:0]     cmd,
    output reg [2*WIDTH-1:0]   res,
    output reg                 oflow, cout, g, l, e, err
);

    reg [2*WIDTH-1:0] prev_res;
    reg               prev_err, prev_oflow, prev_cout, prev_g, prev_l, prev_e;
    reg [WIDTH-1:0]   temp_a, temp_b;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res <= 0; oflow <= 0; cout <= 0;
            g   <= 0; l     <= 0; e    <= 0; err <= 0;
        end
        else if (ce) begin

            // Stage 2: push prev to outputs
            res   <= prev_res;   err   <= prev_err;
            oflow <= prev_oflow; cout  <= prev_cout;
            g     <= prev_g;     l     <= prev_l;     e <= prev_e;

            // Clear prev defaults
            prev_res<=0; prev_err<=0; prev_oflow<=0;
            prev_cout<=0; prev_g<=0; prev_l<=0; prev_e<=0;

            // Stage 1: compute into prev
            if (mode) begin
                case (cmd)
                    0: if (inp_valid==2'b11) begin
                           prev_res  <= opa + opb;
                           prev_cout <= ({1'b0,opa}+{1'b0,opb}) >> WIDTH;
                       end else prev_err <= 1;

                    1: if (inp_valid==2'b11) begin
                           prev_res   <= opa - opb;
                           prev_oflow <= (opa < opb);
                       end else prev_err <= 1;

                    2: if (inp_valid==2'b11) begin
                           prev_res  <= opa + opb + cin;
                           prev_cout <= ({1'b0,opa}+{1'b0,opb}+cin) >> WIDTH;
                       end else prev_err <= 1;

                    3: if (inp_valid==2'b11) begin
                           prev_res   <= opa - opb - cin;
                           prev_oflow <= ({1'b0,opa} < ({1'b0,opb}+cin));
                       end else prev_err <= 1;

                    4: if (inp_valid==2'b11||inp_valid==2'b01) prev_res <= opa+1; else prev_err <= 1;
                    5: if (inp_valid==2'b11||inp_valid==2'b01) prev_res <= opa-1; else prev_err <= 1;
                    6: if (inp_valid==2'b11||inp_valid==2'b10) prev_res <= opb+1; else prev_err <= 1;
                    // CMD=7: spec needs 2'b10. Karan.v Bug1: wrongly uses 2'b01
                    7: if (inp_valid==2'b11||inp_valid==2'b10) prev_res <= opb-1; else prev_err <= 1;

                    8: if (inp_valid==2'b11) begin
                           if      (opa>opb) prev_g<=1;
                           else if (opa<opb) prev_l<=1;
                           else             prev_e<=1;
                       end else prev_err <= 1;

                    // 2-cycle multiply
                    9: if (inp_valid==2'b11) begin
                           temp_a <= opa+1; temp_b <= opb+1;
                           prev_res <= temp_a * temp_b;
                       end else prev_err <= 1;  // Karan.v Bug3: writes res directly

                    10: if (inp_valid==2'b11) begin
                            temp_a <= opa<<1; temp_b <= opb;
                            prev_res <= temp_a * temp_b;
                        end else prev_err <= 1; // Karan.v Bug5: outputs stale result

                    11: if (inp_valid==2'b11) begin
                            if      ($signed(opa)>$signed(opb)) prev_g<=1;
                            else if ($signed(opa)<$signed(opb)) prev_l<=1;
                            else                                prev_e<=1;
                            prev_res   <= $signed(opa)+$signed(opb);
                            prev_oflow <= (opa[WIDTH-1]==opb[WIDTH-1]) &&
                                          ((((opa+opb)>>(WIDTH-1))&1'b1)!=opa[WIDTH-1]);
                        end else prev_err <= 1;

                    12: if (inp_valid==2'b11) begin
                            if      ($signed(opa)>$signed(opb)) prev_g<=1;
                            else if ($signed(opa)<$signed(opb)) prev_l<=1;
                            else                                prev_e<=1;
                            prev_res   <= $signed(opa)-$signed(opb);
                            prev_oflow <= (opa[WIDTH-1]!=opb[WIDTH-1]) &&
                                          ((((opa-opb)>>(WIDTH-1))&1'b1)!=opa[WIDTH-1]);
                        end else prev_err <= 1;

                    // Default: Karan.v Bug2 — no ERR. Spec says ERR=1.
                    default: begin prev_err<=1; prev_res<=0; end
                endcase

            end else begin
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

                    12: if (inp_valid==2'b11) begin
                            if (opb[7:4]!=0) prev_err<=1;
                            case(opb[2:0])
                                0: prev_res<=opa;
                                1: prev_res<={opa[WIDTH-2:0],opa[WIDTH-1]};
                                2: prev_res<={opa[WIDTH-3:0],opa[WIDTH-1:WIDTH-2]};
                                3: prev_res<={opa[WIDTH-4:0],opa[WIDTH-1:WIDTH-3]};
                                4: prev_res<={opa[WIDTH-5:0],opa[WIDTH-1:WIDTH-4]};
                                5: prev_res<={opa[WIDTH-6:0],opa[WIDTH-1:WIDTH-5]};
                                6: prev_res<={opa[WIDTH-7:0],opa[WIDTH-1:WIDTH-6]};
                                7: prev_res<={opa[0],opa[WIDTH-1:1]};
                            endcase
                        end else prev_err<=1;

                    13: if (inp_valid==2'b11) begin
                            if (opb[7:4]!=0) prev_err<=1;
                            case(opb[2:0])
                                0: prev_res<=opa;
                                1: prev_res<={opa[0],opa[WIDTH-1:1]};
                                2: prev_res<={opa[1:0],opa[WIDTH-1:2]};
                                3: prev_res<={opa[2:0],opa[WIDTH-1:3]};
                                4: prev_res<={opa[3:0],opa[WIDTH-1:4]};
                                5: prev_res<={opa[4:0],opa[WIDTH-1:5]};
                                6: prev_res<={opa[5:0],opa[WIDTH-1:6]};
                                7: prev_res<={opa[6:0],opa[WIDTH-1:7]};
                            endcase
                        end else prev_err<=1;

                    default: begin prev_err<=1; prev_res<=0; end
                endcase
            end
        end
    end
endmodule

