module alu_project#(parameter width = 8, cmd_width = 4)(
  input clk, rst, cin, ce, mode,
  input [1:0] inp_valid,
  input [width-1 : 0] opa, opb,
  input [cmd_width-1 : 0] cmd,
  output reg [2*width-1 : 0] res,
  output reg oflow, cout, g, l, e, err
);
  
  reg [width-1 : 0] temp_a, temp_b;
  reg [2*width-1:0]prev_res;
  reg prev_err;
  reg prev_oflow;
  reg prev_g;
  reg prev_l;
  reg prev_e;
  reg prev_cout;
  
  always@(posedge clk or posedge rst)begin
    if(rst)begin
      res <= 'd0;
      oflow <= 'd0;
      cout <= 'd0;
      g <= 0;
      e <= 0;
      l <= 0;
      err <= 0;
    end
    
    else if(ce)begin
      oflow <= 'd0;
      cout <= 'd0;
      err <= 0;
      g <= 0;
      e <= 0;
      l <= 0;
      res <= prev_res;
      err <= prev_err;
      oflow <= prev_oflow;
      g <= prev_g;
      l <= prev_l;
      e <= prev_e;
      cout <= prev_cout;
      prev_oflow <= 'd0;
      prev_cout <= 'd0;
      prev_err <= 0;
      prev_g <= 0;
      prev_e <= 0;
      prev_l <= 0;
      
      if(mode)begin
        case(cmd)
          
          0:begin
            if(inp_valid == 2'b11)begin
                prev_res <= opa + opb;
                prev_cout <= ({1'b0,opa} + {1'b0,opb}) >> width;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          1:begin
            if(inp_valid == 2'b11)begin
                prev_res <= opa - opb;
                prev_oflow <= opa < opb;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          2:begin
            if(inp_valid == 2'b11 )begin
                prev_res <= opa + opb + cin;
                prev_cout <= ({1'b0,opa} + {1'b0,opb} + cin) >> width;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          3:begin
            if(inp_valid == 2'b11)begin
                prev_res <= opa - opb - cin;
              prev_oflow <= opa < {1'b0,opb}+cin;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          4:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b01))begin
              prev_res <= opa + 1;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          5:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b01))begin
              prev_res <= opa - 1;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          6:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b10))begin
              prev_res <= opb + 1;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          7:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b01))begin
              prev_res <= opb - 1;
            end
            else begin
                prev_err <= 1'b1;
            end
          end

          8:begin
            if(inp_valid == 2'b11)begin
              if(opa > opb) prev_g <= 1;
              else if(opa < opb) prev_l <= 1;
              else prev_e <= 1;
            end
            else begin
                prev_err <= 1'b1;
            end
          end
          
          9:begin
            if(inp_valid == 2'b11)begin
              temp_a <= opa+1;
              temp_b <= opb+1;
              prev_res <= temp_a * temp_b;
            end
            else begin
                res <= temp_a * temp_b;
                prev_err <= 1;
            end
          end
          
          10:begin
            if(inp_valid == 2'b11)begin
              temp_a <= opa<<1;
              temp_b <= opb;
              prev_res <= temp_a * temp_b;
            end
            else begin
                prev_res <= temp_a * temp_b;
                prev_err <= 1;
            end
          end
            
          11:begin
            if(inp_valid == 2'b11)begin
              if($signed(opa) > $signed(opb)) prev_g <= 1;
              else if($signed(opa) < $signed(opb)) prev_l <= 1;
              else prev_e <= 1;
        
              prev_res <= $signed(opa) + $signed(opb);
              prev_oflow <= (opa[width-1] == opb[width-1]) && ((((opa + opb) >> (width-1)) & 1'b1) != opa[width-1]);
            end
            else begin
                prev_err <= 1'b1;
            end
          end
          
          12:begin
            if(inp_valid == 2'b11)begin
              if($signed(opa) > $signed(opb)) prev_g <= 1;
              else if($signed(opa) < $signed(opb)) prev_l <= 1;
              else prev_e <= 1;
              
              prev_res <= $signed(opa) - $signed(opb);
              prev_oflow <= (opa[width-1] != opb[width-1]) && ((((opa - opb) >> (width-1)) & 1'b1) != opa[width-1]);
            end 
            else begin
                prev_err <= 1'b1;
            end
          end
          
          default :begin 
            prev_res <= 'd0;
            prev_oflow <= 'd0;
            prev_cout <= 'd0;
            prev_g <= 0;
            prev_e <= 0;
            prev_l <= 0;
          end
        endcase
      end
      
      else begin
        case(cmd)
          
          0:begin
            if(inp_valid == 2'b11)
              prev_res <= opa & opb;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          1:begin
            if(inp_valid == 2'b11)
              prev_res <= ~(opa & opb);
            else begin
                prev_err <= 1'b1;
            end
          end
          
          2:begin
            if(inp_valid == 2'b11)
              prev_res <= opa | opb;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          3:begin
            if(inp_valid == 2'b11)
              prev_res <= ~(opa | opb);
            else begin
                prev_err <= 1'b1;
            end
          end
          
          4:begin
            if(inp_valid == 2'b11)
              prev_res <= opa ^ opb;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          5:begin
            if(inp_valid == 2'b11)
              prev_res <= ~(opa ^ opb);
            else begin
                prev_err <= 1'b1;
            end
          end
          
          6:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b01))
              prev_res <= ~opa;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          7:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b10))
              prev_res <= ~opb;
            else begin
                prev_err <= 1'b1;
            end
          end
            
          8:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b01))
              prev_res <= opa>>1;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          9:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b01))
              prev_res <= opa<<1;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          10:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b10))
              prev_res <= opb>>1;
            else begin
                prev_err <= 1'b1;
            end
          end
          
          11:begin
            if((inp_valid == 2'b11 || inp_valid == 2'b10))
              prev_res <= opb<<1;
            else
              prev_err <= 1'b1;
          end
          
          12:begin
            if(inp_valid == 2'b11)begin
              if(opb[7:4] != 0) prev_err <= 1;
              
              case(opb[2:0])
                0: prev_res <= opa;
                1: prev_res <= {opa[width-2:0], opa[width-1]};
                2: prev_res <= {opa[width-3:0], opa[width-1:width-2]};
                3: prev_res <= {opa[width-4:0], opa[width-1:width-3]};
                4: prev_res <= {opa[width-5:0], opa[width-1:width-4]};
                5: prev_res <= {opa[width-6:0], opa[width-1:width-5]};
                6: prev_res <= {opa[width-7:0], opa[width-1:width-6]};
                7: prev_res <= {opa[width-8:0], opa[width-1:width-7]};
              endcase
            end
            else begin
                prev_err <= 1'b1;
            end
          end
          
          13:begin
            if(inp_valid == 2'b11)begin
              if(opb[7:4] != 0) prev_err <= 1;
              
              case(opb[2:0])
                0: prev_res <= opa;
                1: prev_res <= {opa[0], opa[width-1:1]};
                2: prev_res <= {opa[1:0], opa[width-1:2]};
                3: prev_res <= {opa[2:0], opa[width-1:3]};
                4: prev_res <= {opa[3:0], opa[width-1:4]};
                5: prev_res <= {opa[4:0], opa[width-1:5]};
                6: prev_res <= {opa[5:0], opa[width-1:6]};
                7: prev_res <= {opa[6:0], opa[width-1:7]};
              endcase
            end
            else begin
                prev_err <= 1'b1;
            end
          end
        endcase
      end
    end
  end
endmodule

