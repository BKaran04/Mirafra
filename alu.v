`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/04/2026 03:27:48 PM
// Design Name: 
// Module Name: alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module alu #(parameter DATA_WIDTH = 8, parameter CMD_WIDTH  = 4)(
    input CLK, 
    input RST, 
    input MODE,
    input CE,
    input [1:0]INP_VALID,
    input [CMD_WIDTH-1:0]CMD,
    input [DATA_WIDTH-1:0]OPA,
    input [DATA_WIDTH-1:0]OPB,
    input CIN,
    output reg [(2*DATA_WIDTH)-1:0]RES,
    output reg OFLOW,
    output reg COUT,
    output reg G,
    output reg L,
    output reg E,
    output reg ERR
);
    reg [CMD_WIDTH-1:0]cmd_d;
    reg [1:0]cycle_cnt;
    reg [1:0]inp_valid_d;
    reg [DATA_WIDTH-1:0]opa_d;
    reg [DATA_WIDTH-1:0]opb_d;
    reg cin_d;
    reg [DATA_WIDTH-1:0]mul_op_a;
    reg [DATA_WIDTH-1:0]mul_op_b;
    reg signed [DATA_WIDTH-1:0]opa_signed;
    reg signed [DATA_WIDTH-1:0]opb_signed;
    wire [DATA_WIDTH:0]signed_sum_ext;
    assign signed_sum_ext = $signed(opa_d) + $signed(opb_d);
    always @(posedge CLK) begin
        if (MODE && (CMD == 4'd9 || CMD == 4'd10)) begin
            if (cycle_cnt < 2)
                cycle_cnt <= cycle_cnt + 1'b1;
            else
                cycle_cnt <= 1;
        end
        else begin
            cycle_cnt <= 0;
        end
    end
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            RES    <= 0;
            OFLOW <= 0;
            COUT  <= 0;
            G     <= 0;
            L     <= 0;
            E     <= 0;
            ERR   <= 0;
        end
        else if (CE) begin
            inp_valid_d <= INP_VALID;
            opa_d       <= OPA;
            opb_d       <= OPB;
            cmd_d       <= CMD;
            cin_d       <= CIN;
            OFLOW <= 0;
            COUT  <= 0;
            G     <= 0;
            L     <= 0;
            E     <= 0;
            ERR   <= 0;
            if (MODE) begin
                case (cmd_d)
                    4'd0: begin
                        if (inp_valid_d == 2'b11)
                            {COUT, RES[DATA_WIDTH-1:0]} <= opa_d + opb_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd1: begin
                        if (inp_valid_d == 2'b11) begin
                            OFLOW <= (opa_d < opb_d) ? 1'b1 : 1'b0;
                            RES[DATA_WIDTH-1:0] <= opa_d - opb_d; end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd2: begin
                        if (inp_valid_d == 2'b11)
                            {COUT, RES[DATA_WIDTH-1:0]} <= opa_d + opb_d + cin_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd3: begin
                        if (inp_valid_d == 2'b11)
                            RES[DATA_WIDTH-1:0] <= opa_d - opb_d - cin_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd4: begin
                        if (inp_valid_d == 2'b01)
                            RES[DATA_WIDTH-1:0] <= opa_d + 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd5: begin
                        if (inp_valid_d == 2'b01)
                            RES[DATA_WIDTH-1:0] <= opa_d - 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd6: begin
                        if (inp_valid_d == 2'b10)
                            RES[DATA_WIDTH-1:0] <= opb_d + 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd7: begin
                        if (inp_valid_d == 2'b10)
                            RES[DATA_WIDTH-1:0] <= opb_d - 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd8: begin
                        if (inp_valid_d == 2'b11) begin
                            G <= (opa_d > opb_d);
                            E <= (opa_d == opb_d);
                            L <= (opa_d < opb_d);
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd9: begin
                        if (inp_valid_d == 2'b11) begin
                            if (cycle_cnt == 2'd1) begin
                                mul_op_a <= opa_d + 1;
                                mul_op_b <= opb_d + 1;
                                RES <= 'bx;
                            end
                            else if (cycle_cnt == 2'd2) begin
                                RES <= mul_op_a * mul_op_b;
                            end
                            else begin
                                RES <= RES;
                            end
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd10: begin
                        if (inp_valid_d == 2'b11) begin
                            if (cycle_cnt == 2'd1) begin
                                mul_op_a <= opa_d << 1;
                                RES <= 'bx;
                            end
                            else if (cycle_cnt == 2'd2) begin
                                RES <= mul_op_a * opb_d;
                            end
                            else begin
                                RES <= RES;
                            end
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd11: begin
                        opa_signed = $signed(opa_d);
                        opb_signed = $signed(opb_d);
                        if (inp_valid_d == 2'b11) begin
                            RES <= opa_signed + opb_signed;
                            OFLOW <= (opa_signed[DATA_WIDTH-1] == opb_signed[DATA_WIDTH-1]) && (signed_sum_ext[DATA_WIDTH] != opa_signed[DATA_WIDTH-1]);
                            G <= (opa_signed > opb_signed);
                            E <= (opa_signed == opb_signed);
                            L <= (opa_signed < opb_signed);
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd12: begin
                        opa_signed = opa_d;
                        opb_signed = opb_d;
                        if (inp_valid_d == 2'b11) begin
                            RES <= opa_signed - opb_signed;
                            OFLOW <= (opa_signed[DATA_WIDTH-1] != opb_signed[DATA_WIDTH-1]) && (signed_sum_ext[DATA_WIDTH] != opa_signed[DATA_WIDTH-1]);
                            G <= (opa_signed > opb_signed);
                            E <= (opa_signed == opb_signed);
                            L <= (opa_signed < opb_signed);
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    default: begin
                        ERR <= 1;
                        RES <= 0;
                    end
                endcase
            end
            else begin
                case (cmd_d)
                    4'd0: begin
                        if (inp_valid_d == 2'b11)
                            RES <= opa_d & opb_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd1: begin
                        if (inp_valid_d == 2'b11)
                            RES <= ~(opa_d & opb_d);
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd2: begin
                        if (inp_valid_d == 2'b11)
                            RES <= opa_d | opb_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd3: begin
                        if (inp_valid_d == 2'b11)
                            RES <= ~(opa_d | opb_d);
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end

                    4'd4: begin
                        if (inp_valid_d == 2'b11)
                            RES <= opa_d ^ opb_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd5: begin
                        if (inp_valid_d == 2'b11)
                            RES <= ~(opa_d ^ opb_d);
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end

                    4'd6: begin
                        if (inp_valid_d == 2'b01)
                            RES <= ~opa_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd7: begin
                        if (inp_valid_d == 2'b10)
                            RES <= ~opb_d;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd8: begin
                        if (inp_valid_d == 2'b01)
                            RES <= opa_d >> 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd9: begin
                        if (inp_valid_d == 2'b01)
                            RES <= opa_d << 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd10: begin
                        if (inp_valid_d == 2'b10)
                            RES <= opb_d >> 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd11: begin
                        if (inp_valid_d == 2'b10)
                            RES <= opb_d << 1;
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd12: begin
                        if (inp_valid_d == 2'b11) begin
                            RES[DATA_WIDTH-1:0] <= (opa_d << (opb_d[$clog2(DATA_WIDTH)-1:0])) | (opa_d >> (DATA_WIDTH - opb_d[$clog2(DATA_WIDTH)-1:0]));
                            if (opb_d[DATA_WIDTH-1:4] != 0)
                                ERR <= 1;
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    4'd13: begin
                        if (inp_valid_d == 2'b11) begin
                            RES[DATA_WIDTH-1:0] <= (opa_d >> (opb_d[$clog2(DATA_WIDTH)-1:0])) | (opa_d << (DATA_WIDTH - opb_d[$clog2(DATA_WIDTH)-1:0]));
                            if (opb_d[DATA_WIDTH-1:4] != 0)
                                ERR <= 1;
                        end
                        else begin
                            ERR <= 1;
                            RES <= 0;
                        end
                    end
                    default: begin
                        ERR <= 1;
                        RES <= 0;
                    end
                endcase
            end
        end
        else begin
            RES <= 0;
        end
    end
endmodule











