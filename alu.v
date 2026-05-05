module alu #(parameter DATA_WIDTH = 8, parameter CMD_WIDTH  = 4)(OPA, OPB, CIN, CLK, RST, CMD, CE, MODE, INP_VALID, COUT, OFLOW, RES, G, E, L, ERR);

  input  [DATA_WIDTH-1:0]OPA, OPB;   // Parameterized operands
  input  CLK;                        // Clock (edge-sensitive)
  input  RST;                        // Active-high asynchronous reset
  input  CE;                         // Active-high clock enable
  input  MODE;                       // 1 = Arithmetic, 0 = Logical
  input  CIN;                        // Carry-in (1-bit)
  input  [CMD_WIDTH-1:0]CMD;         // Command (parameterized width, default 4-bit)
  input  [1:0]INP_VALID;             // 00=none, 01=OPA, 10=OPB, 11=both
  output reg [2*DATA_WIDTH-1:0]RES = {(2*DATA_WIDTH){1'bz}}; // Result is DATA_WIDTH+1 bits wide to capture carry/overflow from the MSB
  output reg COUT  = 1'bz;
  output reg OFLOW = 1'bz;
  output reg G     = 1'bz;   // OPA > OPB
  output reg E     = 1'bz;   // OPA = OPB
  output reg L     = 1'bz;   // OPA < OPB
  output reg ERR   = 1'bz;
  localparam RES_Z  = {(2*DATA_WIDTH){1'bz}};  // Z value for RES
  localparam ROT_BITS = $clog2(DATA_WIDTH);   // log2(DATA_WIDTH)
  reg [DATA_WIDTH-1:0]OPA_1;
  reg [ROT_BITS-1:0]rot_amt;   // Rotation amount from OPB[ROT_BITS-1:0]
  reg [1:0]mul_cnt;               // 2-bit counter: 0 = idle, 1 = wait, 2 = output
  reg [DATA_WIDTH-1:0] mul_A;     // Pre-computed operand A (latched at count 0)
  reg [DATA_WIDTH-1:0] mul_B;     
  reg [2*DATA_WIDTH-1:0]temp;
  reg signed [2*DATA_WIDTH-1:0]temp_s;
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
      begin
        mul_cnt <= 2'd0;
        mul_A   <= {DATA_WIDTH{1'b0}};
        mul_B   <= {DATA_WIDTH{1'b0}};
      end
    else if (CE)
      begin
        if (mul_cnt == 2'd0)
          begin
            if (MODE && INP_VALID == 2'b11 && (CMD == 9 || CMD == 10))
              begin
                if (CMD == 9)
                  begin
                    mul_A <= OPA + 1;    
                    mul_B <= OPB + 1;    
                  end
                else
                  begin
                    mul_A <= OPA << 1;   
                    mul_B <= OPB;        
                  end
                mul_cnt <= 2'd1;      
              end
          end
        else if (mul_cnt == 2'd1)
          mul_cnt <= 2'd2;               
        else if (mul_cnt == 2'd2)
          mul_cnt <= 2'd0;              
      end
  end
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
      begin
        RES   <= RES_Z;
        COUT  <= 1'bz;
        OFLOW <= 1'bz;
        G     <= 1'bz;
        E     <= 1'bz;
        L     <= 1'bz;
        ERR   <= 1'bz;
      end
    else if (CE)
      begin
        if (MODE)
          begin
            RES   <= RES_Z; // Default outputs to high-impedance before evaluating the command
            COUT  <= 1'bz;
            OFLOW <= 1'bz;
            G     <= 1'bz;
            E     <= 1'bz;
            L     <= 1'bz;
            ERR   <= 1'bz;
            case(CMD)
              0:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp = OPA + OPB;
                      RES <= temp;
                      COUT <= temp[DATA_WIDTH] ? 1'b1 : 1'b0;
                    end
                end
              1:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp = OPA - OPB;
                      OFLOW <= (OPA[DATA_WIDTH-1] ^ OPB[DATA_WIDTH-1]) & (OPA[DATA_WIDTH-1] ^ temp[DATA_WIDTH-1]);                    
                      RES <= temp;
                    end
                end
              2:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp = OPA + OPB + CIN;
                      RES <= temp;
                      COUT <= temp[DATA_WIDTH] ? 1'b1 : 1'b0;
                    end
                end
              3:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp = OPA - OPB - CIN;
                      OFLOW <= (OPA[DATA_WIDTH-1] ^ OPB[DATA_WIDTH-1]) & (OPA[DATA_WIDTH-1] ^ temp[DATA_WIDTH-1]);
                      RES <= temp;
                    end
                end
              4:
                begin
                  if (INP_VALID == 2'b01) begin
                    temp = OPA + 1;
                    RES <= temp; end
                end
              5:
                begin
                  if (INP_VALID == 2'b01) begin
                    temp = OPA - 1;
                    RES <= temp; end
                end
              6:
                begin
                  if (INP_VALID == 2'b10) begin
                    temp = OPB + 1;
                    RES <= temp; end
                end
              7:
                begin
                  if (INP_VALID == 2'b10) begin
                    temp = OPB - 1;
                    RES <= temp; end
                end
              8:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp = RES_Z;
                      RES <= temp;
                      if (OPA == OPB)
                        begin E <= 1'b1; G <= 1'bz; L <= 1'bz; end
                      else if (OPA > OPB)
                        begin E <= 1'bz; G <= 1'b1; L <= 1'bz; end
                      else
                        begin E <= 1'bz; G <= 1'bz; L <= 1'b1; end
                    end
                end
              9:
                begin
                  if (mul_cnt == 2'd2)
                    begin
                      temp = mul_A * mul_B;
                      RES <= temp;
                    end
                end
             10:
                begin
                  if (mul_cnt == 2'd2)
                    begin
                      temp = mul_A * mul_B;
                      RES <= temp;
                    end
                end
             11:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp_s = $signed(OPA) + $signed(OPB);
                      RES <= temp_s;
                      COUT <= temp_s[0];
                      OFLOW <= (~OPA[DATA_WIDTH-1] & ~OPB[DATA_WIDTH-1] & temp_s[DATA_WIDTH-1]) | (OPA[DATA_WIDTH-1] & OPB[DATA_WIDTH-1] & ~temp_s[DATA_WIDTH-1]);
                      if ($signed(OPA) > $signed(OPB))
                        begin G <= 1'b1; L <= 1'bz; E <= 1'bz; end
                      else if ($signed(OPA) < $signed(OPB))
                        begin G <= 1'bz; L <= 1'b1; E <= 1'bz; end
                      else
                        begin G <= 1'bz; L <= 1'bz; E <= 1'b1; end
                    end
                end
             12:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      temp_s = $signed(OPA) - $signed(OPB);
                      RES <= temp_s;
                      COUT <= temp_s[0];
                      OFLOW <= (OPA[DATA_WIDTH-1] ^ OPB[DATA_WIDTH-1]) & (OPA[DATA_WIDTH-1] ^ temp_s[DATA_WIDTH-1]);                 
                      if ($signed(OPA) > $signed(OPB))
                        begin G <= 1'b1; L <= 1'bz; E <= 1'bz; end
                      else if ($signed(OPA) < $signed(OPB))
                        begin G <= 1'bz; L <= 1'b1; E <= 1'bz; end
                      else
                        begin G <= 1'bz; L <= 1'bz; E <= 1'b1; end
                    end
                end
              default:
                begin
                  RES   <= RES_Z;
                  COUT  <= 1'bz;
                  OFLOW <= 1'bz;
                  G     <= 1'bz;
                  E     <= 1'bz;
                  L     <= 1'bz;
                  ERR   <= 1'bz;
                end
            endcase
          end 
        else
          begin
            RES   <= RES_Z;
            COUT  <= 1'bz;
            OFLOW <= 1'bz;
            G     <= 1'bz;
            E     <= 1'bz;
            L     <= 1'bz;
            ERR   <= 1'bz;
            case(CMD)
              0:
                begin
                  if (INP_VALID == 2'b11) begin
                    temp = {1'b0, OPA & OPB};
                    RES <= temp; end
                end
              1:
                begin
                  if (INP_VALID == 2'b11) begin
                    temp = {1'b0, ~(OPA & OPB)};
                    RES <= temp; end
                end
              2:
                begin
                  if (INP_VALID == 2'b11) begin
                    temp = {1'b0, OPA | OPB};
                    RES <= temp; end
                end
              3:
                begin
                  if (INP_VALID == 2'b11) begin
                    temp = {1'b0, ~(OPA | OPB)};
                    RES <= temp; end
                end
              4:
                begin
                  if (INP_VALID == 2'b11) begin
                    temp = {1'b0, OPA ^ OPB};
                    RES <= temp; end
                end
              5:
                begin
                  if (INP_VALID == 2'b11) begin
                    temp = {1'b0, ~(OPA ^ OPB)};
                    RES <= temp; end
                end
              6:
                begin
                  if (INP_VALID == 2'b01) begin
                    temp = {1'b0, ~OPA};
                    RES <= temp; end
                end
              7:
                begin
                  if (INP_VALID == 2'b10) begin
                    temp = {1'b0, ~OPB};
                    RES <= temp; end
                end
              8:
                begin
                  if (INP_VALID == 2'b01) begin
                    temp = {1'b0, OPA >> 1};
                    RES <= temp; end
                end
              9:
                begin
                  if (INP_VALID == 2'b01) begin
                    temp = {1'b0, OPA << 1};
                    RES <= temp; end
                end
             10:
                begin
                  if (INP_VALID == 2'b10) begin
                    temp = {1'b0, OPB >> 1};
                    RES <= temp; end
                end
             11:
                begin
                  if (INP_VALID == 2'b10) begin
                    temp = {1'b0, OPB << 1};
                    RES <= temp; end
                end
             12:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      rot_amt = OPB[ROT_BITS-1:0];
                      case (rot_amt)
                        3'd0: OPA_1 = OPA;
                        3'd1: OPA_1 = {OPA[DATA_WIDTH-2:0], OPA[DATA_WIDTH-1]};
                        3'd2: OPA_1 = {OPA[DATA_WIDTH-3:0], OPA[DATA_WIDTH-1:DATA_WIDTH-2]};
                        3'd3: OPA_1 = {OPA[DATA_WIDTH-4:0], OPA[DATA_WIDTH-1:DATA_WIDTH-3]};
                        3'd4: OPA_1 = {OPA[DATA_WIDTH-5:0], OPA[DATA_WIDTH-1:DATA_WIDTH-4]};
                        3'd5: OPA_1 = {OPA[DATA_WIDTH-6:0], OPA[DATA_WIDTH-1:DATA_WIDTH-5]};
                        3'd6: OPA_1 = {OPA[DATA_WIDTH-7:0], OPA[DATA_WIDTH-1:DATA_WIDTH-6]};
                        3'd7: OPA_1 = {OPA[0], OPA[DATA_WIDTH-1:1]};
                        default: OPA_1 = OPA;
                      endcase
                      temp = {1'b0, OPA_1};
                      RES <= temp;
                      if (|OPB[DATA_WIDTH-1:4])
                        ERR <= 1'b1;
                    end
                end
             13:
                begin
                  if (INP_VALID == 2'b11)
                    begin
                      rot_amt = OPB[ROT_BITS-1:0];
                      case (rot_amt)
                        3'd0: OPA_1 = OPA;
                        3'd1: OPA_1 = {OPA[0], OPA[DATA_WIDTH-1:1]};
                        3'd2: OPA_1 = {OPA[1:0], OPA[DATA_WIDTH-1:2]};
                        3'd3: OPA_1 = {OPA[2:0], OPA[DATA_WIDTH-1:3]};
                        3'd4: OPA_1 = {OPA[3:0], OPA[DATA_WIDTH-1:4]};
                        3'd5: OPA_1 = {OPA[4:0], OPA[DATA_WIDTH-1:5]};
                        3'd6: OPA_1 = {OPA[5:0], OPA[DATA_WIDTH-1:6]};
                        3'd7: OPA_1 = {OPA[DATA_WIDTH-2:0], OPA[DATA_WIDTH-1]};
                        default: OPA_1 = OPA;
                      endcase
                      temp = {1'b0, OPA_1};
                      RES <= temp;
                      if (|OPB[DATA_WIDTH-1:4])
                        ERR <= 1'b1;
                    end
                end
              default:
                begin
                  RES   <= RES_Z;
                  COUT  <= 1'bz;
                  OFLOW <= 1'bz;
                  G     <= 1'bz;
                  E     <= 1'bz;
                  L     <= 1'bz;
                  ERR   <= 1'bz;
                end
            endcase
          end 
      end 
  end 
endmodule
