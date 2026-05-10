//=============================================================================
// Self-Checking Testbench — alu_project (Karan.v)
// 118 test cases from test plan, mapped 1-to-1
// DUT vs Reference Model — mismatch = FAIL = bug found
//=============================================================================
`timescale 1ns/1ps

module alu_tb;

    // ── Ports ────────────────────────────────────────────────────────────────
    reg        clk, rst, cin, ce, mode;
    reg  [1:0] inp_valid;
    reg  [7:0] opa, opb;
    reg  [3:0] cmd;

    wire [15:0] dut_res,  ref_res;
    wire        dut_oflow,ref_oflow;
    wire        dut_cout, ref_cout;
    wire        dut_g,    ref_g;
    wire        dut_l,    ref_l;
    wire        dut_e,    ref_e;
    wire        dut_err,  ref_err;

    // ── DUT ──────────────────────────────────────────────────────────────────
    alu_project DUT (
        .clk(clk),.rst(rst),.cin(cin),.ce(ce),.mode(mode),
        .inp_valid(inp_valid),.opa(opa),.opb(opb),.cmd(cmd),
        .res(dut_res),.oflow(dut_oflow),.cout(dut_cout),
        .g(dut_g),.l(dut_l),.e(dut_e),.err(dut_err)
    );

    // ── Reference Model ───────────────────────────────────────────────────────
    alu_ref_model REF (
        .clk(clk),.rst(rst),.cin(cin),.ce(ce),.mode(mode),
        .inp_valid(inp_valid),.opa(opa),.opb(opb),.cmd(cmd),
        .res(ref_res),.oflow(ref_oflow),.cout(ref_cout),
        .g(ref_g),.l(ref_l),.e(ref_e),.err(ref_err)
    );

    // ── Clock ─────────────────────────────────────────────────────────────────
    initial clk = 0;
    always  #5 clk = ~clk;

    // ── Scoreboard ────────────────────────────────────────────────────────────
    integer pass_cnt = 0, fail_cnt = 0;

    // ── TASKS ─────────────────────────────────────────────────────────────────

    // Reset both DUT and ref model
    task reset;
        begin
            @(negedge clk);
            rst=1; ce=0; cin=0; mode=0; opa=0; opb=0; cmd=0; inp_valid=0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            @(negedge clk); rst=0;
        end
    endtask

    // Drive inputs
    task drive;
        input [7:0]  i_opa, i_opb;
        input [3:0]  i_cmd;
        input        i_mode, i_cin;
        input [1:0]  i_inv;
        begin
            @(negedge clk);
            opa=i_opa; opb=i_opb; cmd=i_cmd;
            mode=i_mode; cin=i_cin; inp_valid=i_inv; ce=1;
        end
    endtask

    // Wait N rising edges
    task wait_n;
        input integer n; integer i;
        begin for(i=0;i<n;i=i+1) @(posedge clk); #1; end
    endtask

    // Compare DUT vs ref and print result
    // chk_res/oflow/cout/gle/err: 1=check that signal, 0=skip
    task check;
        input integer       tc_num;
        input [200*8-1:0]   tc_name;
        input               chk_res, chk_oflow, chk_cout, chk_gle, chk_err;
        reg                 fail;
        begin
            fail = 0;
            if (chk_res   && dut_res   !== ref_res)   begin $display("    RES  : DUT=%0h REF=%0h",   dut_res,dut_res,ref_res);   fail=1; end
            if (chk_oflow && dut_oflow !== ref_oflow) begin $display("    OFLOW: DUT=%0b REF=%0b",   dut_oflow,ref_oflow); fail=1; end
            if (chk_cout  && dut_cout  !== ref_cout)  begin $display("    COUT : DUT=%0b REF=%0b",   dut_cout,ref_cout);  fail=1; end
            if (chk_gle) begin
                if (dut_g!==ref_g) begin $display("    G    : DUT=%0b REF=%0b",dut_g,ref_g); fail=1; end
                if (dut_l!==ref_l) begin $display("    L    : DUT=%0b REF=%0b",dut_l,ref_l); fail=1; end
                if (dut_e!==ref_e) begin $display("    E    : DUT=%0b REF=%0b",dut_e,ref_e); fail=1; end
            end
            if (chk_err   && dut_err   !== ref_err)   begin $display("    ERR  : DUT=%0b REF=%0b",   dut_err,ref_err);   fail=1; end

            if (fail) begin
                $display("FAIL TC%-3d [%0s]  opa=%0h opb=%0h cmd=%0d mode=%0b inv=%0b cin=%0b",
                         tc_num,tc_name,opa,opb,cmd,mode,inp_valid,cin);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS TC%0d [%0s]", tc_num, tc_name);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // Standard 1-cycle test: reset → drive → wait 2 clk → check
    task tc1;
        input integer      num;
        input [200*8-1:0]  name;
        input [7:0]        i_opa, i_opb;
        input [3:0]        i_cmd;
        input              i_mode, i_cin;
        input [1:0]        i_inv;
        input              c_res, c_oflow, c_cout, c_gle, c_err;
        begin
            reset;
            drive(i_opa,i_opb,i_cmd,i_mode,i_cin,i_inv);
            wait_n(2);
            check(num,name,c_res,c_oflow,c_cout,c_gle,c_err);
        end
    endtask

    // 2-cycle multiply test: apply same inputs twice
    task tc_mul;
        input integer      num;
        input [200*8-1:0]  name;
        input [7:0]        i_opa, i_opb;
        input [3:0]        i_cmd;
        begin
            reset;
            drive(i_opa,i_opb,i_cmd,1'b1,1'b0,2'b11);
            wait_n(1);
            drive(i_opa,i_opb,i_cmd,1'b1,1'b0,2'b11);
            wait_n(2);
            check(num,name,1,0,0,0,0);
        end
    endtask

    // ── TEST SEQUENCE ─────────────────────────────────────────────────────────
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0,alu_tb);
        rst=1; ce=0; cin=0; mode=0; opa=0; opb=0; cmd=0; inp_valid=0;
        @(posedge clk); @(posedge clk); #1; rst=0;

        $display("\n====================================================");
        $display("  ALU TESTBENCH  —  118 Test Cases");
        $display("====================================================\n");

        // ------ TC1: CLK -------------------------------------------------------
        begin reset; pass_cnt=pass_cnt+1;
            $display("PASS TC1  [clk_toggle] simulation running = clock OK"); end

        // ------ TC2: RST -------------------------------------------------------
        begin
            @(negedge clk); rst=1; ce=1; mode=1; cmd=0;
            opa=8'hFF; opb=8'hFF; inp_valid=2'b11;
            @(posedge clk); #1;
            if (dut_res===0&&dut_err===0&&dut_oflow===0&&dut_cout===0&&dut_g===0&&dut_l===0&&dut_e===0)
                begin $display("PASS TC2  [async_reset]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC2  [async_reset]"); fail_cnt=fail_cnt+1; end
            @(negedge clk); rst=0;
        end

        // ------ TC3: RST during op ---------------------------------------------
        begin
            @(negedge clk); rst=0; ce=1; mode=1; cmd=0;
            opa=8'hAA; opb=8'h55; inp_valid=2'b11;
            @(posedge clk); #1;
            @(negedge clk); rst=1;
            @(posedge clk); #1;
            if (dut_res===0&&dut_err===0&&dut_oflow===0)
                begin $display("PASS TC3  [rst_during_op]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC3  [rst_during_op]"); fail_cnt=fail_cnt+1; end
            @(negedge clk); rst=0;
        end

        // ------ TC4: CE enable -------------------------------------------------
        begin
            reset; drive(8'h05,8'h03,4'd0,1,0,2'b11); wait_n(2);
            if (dut_res===16'h0008)
                begin $display("PASS TC4  [ce_enable]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC4  [ce_enable] res=%0h",dut_res); fail_cnt=fail_cnt+1; end
        end

        // ------ TC5: CE disable holds output -----------------------------------
        begin : ce_hold
            reg [15:0] held;
            reset; drive(8'h05,8'h03,4'd0,1,0,2'b11); wait_n(2); held=dut_res;
            @(negedge clk); ce=0; opa=8'hFF; opb=8'hFF;
            @(posedge clk); #1;
            if (dut_res===held)
                begin $display("PASS TC5  [ce_disable]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC5  [ce_disable]"); fail_cnt=fail_cnt+1; end
        end

        // ------ TC6-22: ARITHMETIC MODE=1 -------------------------------------
        //            name                 opa    opb  cmd  mo ci inv  res of co gl er
        tc1(6,  "add_without_cout",  8'h05,8'h03,4'd0, 1,0,2'b11, 1, 0, 1, 0, 0);
        tc1(7,  "add_with_cout",     8'hA5,8'hA6,4'd0, 1,0,2'b11, 1, 0, 1, 0, 0);
        tc1(8,  "sub_a_equal_b",     8'h07,8'h07,4'd1, 1,0,2'b11, 1, 1, 0, 0, 0);
        tc1(9,  "sub_a_less_b",      8'h06,8'h07,4'd1, 1,0,2'b11, 1, 1, 0, 0, 0);
        tc1(10, "sub_a_great_b",     8'h07,8'h05,4'd1, 1,0,2'b11, 1, 1, 0, 0, 0);
        tc1(11, "add_cin_no_cout",   8'h01,8'h01,4'd2, 1,1,2'b11, 1, 0, 1, 0, 0);
        tc1(12, "add_cin_cout",      8'hA6,8'hA7,4'd2, 1,1,2'b11, 1, 0, 1, 0, 0);
        tc1(13, "sub_cin_equal",     8'h05,8'h05,4'd3, 1,1,2'b11, 1, 1, 0, 0, 0);
        tc1(14, "sub_cin_lessthan",  8'h04,8'h05,4'd3, 1,1,2'b11, 1, 1, 0, 0, 0);
        tc1(15, "sub_cin_borrow",    8'h02,8'h01,4'd3, 1,1,2'b11, 1, 1, 0, 0, 0);
        tc1(16, "increment_a",       8'h08,8'h00,4'd4, 1,0,2'b01, 1, 0, 0, 0, 0);
        tc1(17, "decrement_a",       8'h08,8'h00,4'd5, 1,0,2'b01, 1, 0, 0, 0, 0);
        tc1(18, "increment_b",       8'h00,8'h08,4'd6, 1,0,2'b10, 1, 0, 0, 0, 0);
        tc1(19, "decrement_b",       8'h00,8'h08,4'd7, 1,0,2'b10, 1, 0, 0, 0, 0);
        tc1(20, "a_equal_b",         8'h09,8'h09,4'd8, 1,0,2'b11, 0, 0, 0, 1, 0);
        tc1(21, "a_less_b",          8'h07,8'h09,4'd8, 1,0,2'b11, 0, 0, 0, 1, 0);
        tc1(22, "a_greater_b",       8'h09,8'h07,4'd8, 1,0,2'b11, 0, 0, 0, 1, 0);

        // ------ TC23-35: MULTIPLY (2-cycle) ------------------------------------
        tc_mul(23,"mul_basic",       8'h02,8'h03,4'd9);
        tc_mul(24,"mul_zero_opa",    8'h00,8'h04,4'd9);
        tc_mul(25,"mul_zero_opb",    8'h04,8'h00,4'd9);
        tc_mul(26,"mul_one_one",     8'h00,8'h00,4'd9);
        tc_mul(27,"mul_max",         8'hFF,8'hFF,4'd9);

        // TC28: cycle1 stale — just check no ERR is asserted
        begin
            reset; drive(8'h02,8'h03,4'd9,1,0,2'b11); wait_n(1);
            if (dut_err===0)
                begin $display("PASS TC28 [mul_cycle1_no_err]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC28 [mul_cycle1_no_err]"); fail_cnt=fail_cnt+1; end
        end

        // TC29: mul invalid — Bug3 in Karan.v (writes res directly instead of prev_err only)
        tc1(29,"mul_inp_invalid",    8'h02,8'h03,4'd9,  1,0,2'b01, 1, 0, 0, 0, 1);

        tc_mul(30,"mul2x_basic",     8'h03,8'h04,4'd10);
        tc_mul(31,"mul2x_zero_opa",  8'h00,8'h05,4'd10);
        tc_mul(32,"mul2x_zero_opb",  8'h04,8'h00,4'd10);
        tc_mul(33,"mul2x_max",       8'hFF,8'hFF,4'd10);

        // TC34: cycle1 stale
        begin
            reset; drive(8'h03,8'h04,4'd10,1,0,2'b11); wait_n(1);
            if (dut_err===0)
                begin $display("PASS TC34 [mul2x_cycle1_no_err]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC34 [mul2x_cycle1_no_err]"); fail_cnt=fail_cnt+1; end
        end

        // TC35: mul2x invalid — Bug5 in Karan.v (outputs stale result)
        tc1(35,"mul2x_inp_invalid",  8'h03,8'h04,4'd10, 1,0,2'b10, 1, 0, 0, 0, 1);

        // ------ TC36-42: SIGNED ARITHMETIC ------------------------------------
        tc1(36,"signed_add_pp",      8'h05,8'h03,4'd11, 1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(37,"signed_add_nn",      8'hFD,8'hFE,4'd11, 1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(38,"signed_add_pn_zero", 8'h08,8'hF8,4'd11, 1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(39,"signed_add_equal",   8'h05,8'h05,4'd11, 1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(40,"signed_sub_a_gt_b",  8'h08,8'hFD,4'd12, 1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(41,"signed_sub_a_lt_b",  8'hFD,8'h08,4'd12, 1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(42,"signed_sub_equal",   8'hFB,8'hFD,4'd12, 1,0,2'b11, 1, 1, 0, 1, 0);

        // ------ TC43-60: LOGICAL MODE=0 ---------------------------------------
        tc1(43,"and_zero_mask",      8'hFF,8'h00,4'd0,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(44,"and_ff_mask",        8'hA5,8'hFF,4'd0,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(45,"nand_ff_mask",       8'hA5,8'hFF,4'd1,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(46,"nand_zero_mask",     8'hA5,8'h00,4'd1,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(47,"or_zero_mask",       8'hA5,8'h00,4'd2,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(48,"or_ff_mask",         8'h00,8'hFF,4'd2,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(49,"nor_zero_mask",      8'hA5,8'h00,4'd3,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(50,"nor_ff_mask",        8'h00,8'hFF,4'd3,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(51,"xor_same",           8'hA5,8'hA5,4'd4,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(52,"xor_inv",            8'hA5,8'h5A,4'd4,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(53,"xnor_same",          8'hA5,8'hA5,4'd5,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(54,"xnor_inv",           8'hA5,8'h5A,4'd5,  0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(55,"not_a_zero",         8'h00,8'h00,4'd6,  0,0,2'b01, 1, 0, 0, 0, 0);
        tc1(56,"not_b_ff",           8'h00,8'hFF,4'd7,  0,0,2'b10, 1, 0, 0, 0, 0);
        tc1(57,"shr_a_lsb",          8'h02,8'h00,4'd8,  0,0,2'b01, 1, 0, 0, 0, 0);
        tc1(58,"shl_a_msb",          8'h02,8'h00,4'd9,  0,0,2'b01, 1, 0, 0, 0, 0);
        tc1(59,"shr_b_lsb",          8'h00,8'h02,4'd10, 0,0,2'b10, 1, 0, 0, 0, 0);
        tc1(60,"shl_b_msb",          8'h00,8'h02,4'd11, 0,0,2'b10, 1, 0, 0, 0, 0);

        // ------ TC61-69: ROTATE RIGHT -----------------------------------------
        tc1(61,"ror_0",              8'h80,8'h00,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(62,"ror_1",              8'h01,8'h01,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(63,"ror_2",              8'h01,8'h02,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(64,"ror_3",              8'h08,8'h03,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(65,"ror_4",              8'hF0,8'h04,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(66,"ror_5",              8'h80,8'h05,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(67,"ror_6",              8'h80,8'h06,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(68,"ror_7",              8'h80,8'h07,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(69,"ror_all_ones",       8'hFF,8'h05,4'd13, 0,0,2'b11, 1, 0, 0, 0, 0);

        // ------ TC70-79: ROTATE ERROR CASES -----------------------------------
        tc1(70,"Error_ROL_opb10",    8'h01,8'h10,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(71,"Error_ROL_opb20",    8'h01,8'h20,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(72,"Error_ROL_opb40",    8'h01,8'h40,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(73,"Error_ROL_opb80",    8'h01,8'h80,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(74,"Error_ROL_inv",      8'h01,8'h01,4'd13, 0,0,2'b01, 1, 0, 0, 0, 1);
        tc1(75,"Error_ROR_opb10",    8'h01,8'h10,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(76,"Error_ROR_opb20",    8'h01,8'h20,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(77,"Error_ROR_opb40",    8'h01,8'h40,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(78,"Error_ROR_opb80",    8'h01,8'h80,4'd13, 0,0,2'b11, 1, 0, 0, 0, 1);
        tc1(79,"Error_ROR_inv",      8'h01,8'h01,4'd13, 0,0,2'b01, 1, 0, 0, 0, 1);

        // ------ TC80-94: INP_VALID NEGATIVE CASES -----------------------------
        tc1(80, "inv_add_00",        8'h05,8'h03,4'd0, 1,0,2'b00, 1, 0, 0, 0, 1);
        tc1(81, "inv_add_01",        8'h05,8'h03,4'd0, 1,0,2'b01, 1, 0, 0, 0, 1);
        tc1(82, "inv_add_10",        8'h05,8'h03,4'd0, 1,0,2'b10, 1, 0, 0, 0, 1);
        tc1(83, "inv_sub_00",        8'h05,8'h03,4'd1, 1,0,2'b00, 1, 0, 0, 0, 1);
        tc1(84, "inv_sub_01",        8'h05,8'h03,4'd1, 1,0,2'b01, 1, 0, 0, 0, 1);
        tc1(85, "inv_sub_10",        8'h05,8'h03,4'd1, 1,0,2'b10, 1, 0, 0, 0, 1);
        tc1(86, "inv_inc_opa_10",    8'h05,8'h00,4'd4, 1,0,2'b10, 1, 0, 0, 0, 1);
        tc1(87, "inv_dec_opa_00",    8'h05,8'h00,4'd5, 1,0,2'b00, 1, 0, 0, 0, 1);
        tc1(88, "inv_inc_opb_01",    8'h00,8'h05,4'd6, 1,0,2'b01, 1, 0, 0, 0, 1);
        // TC89: DEC OPB — Bug1: Karan.v accepts 2'b01 but spec says only 2'b10/2'b11 valid
        //       Test drives 2'b01 → ref model says ERR=1, DUT says no ERR → FAIL = bug caught
        tc1(89, "inv_dec_opb_01",    8'h00,8'h05,4'd7, 1,0,2'b01, 1, 0, 0, 0, 1);
        tc1(90, "inv_logic_and_01",  8'hAA,8'h55,4'd0, 0,0,2'b01, 1, 0, 0, 0, 1);
        tc1(91, "inv_notA_00",       8'hAA,8'h00,4'd6, 0,0,2'b00, 1, 0, 0, 0, 1);
        tc1(92, "inv_notB_01",       8'h00,8'hF0,4'd7, 0,0,2'b01, 1, 0, 0, 0, 1);
        tc1(93, "inv_shr_a_10",      8'h40,8'h00,4'd8, 0,0,2'b10, 1, 0, 0, 0, 1);
        tc1(94, "inv_shr_b_01",      8'h00,8'h40,4'd10,0,0,2'b01, 1, 0, 0, 0, 1);

        // ------ TC95-101: CONTROL CASES ---------------------------------------

        // TC95: CE=0 outputs stay 0 after reset
        begin
            reset;
            @(negedge clk); ce=0; mode=1; cmd=0; opa=8'hFF; opb=8'hFF; inp_valid=2'b11;
            @(posedge clk); #1;
            if (dut_res===0)
                begin $display("PASS TC95 [ce_low_res_zero]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC95 [ce_low_res_zero]"); fail_cnt=fail_cnt+1; end
        end

        // TC96: CE toggle mid multiply — output should hold
        begin : tc96
            reg [15:0] held;
            reset;
            drive(8'h01,8'h01,4'd0,1,0,2'b11); wait_n(2); held=dut_res;
            drive(8'h02,8'h03,4'd9,1,0,2'b11); wait_n(1);
            @(negedge clk); ce=0; @(posedge clk); #1;
            if (dut_res===held)
                begin $display("PASS TC96 [ce_toggle_mid_mul]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC96 [ce_toggle_mid_mul]"); fail_cnt=fail_cnt+1; end
        end

        // TC97: RST during multiply cycle2
        begin
            reset;
            drive(8'h02,8'h03,4'd9,1,0,2'b11); wait_n(1);
            @(negedge clk); rst=1; @(posedge clk); #1;
            if (dut_res===0&&dut_err===0&&dut_oflow===0&&dut_g===0&&dut_l===0&&dut_e===0)
                begin $display("PASS TC97 [rst_during_mul]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC97 [rst_during_mul]"); fail_cnt=fail_cnt+1; end
            @(negedge clk); rst=0;
        end

        // TC98: Default arith CMD=13 — Bug2: Karan.v no ERR, spec says ERR=1
        tc1(98, "default_arith_cmd13",8'h01,8'h01,4'd13,1,0,2'b11, 1, 0, 0, 0, 1);
        // TC99: Default logic CMD=14
        tc1(99, "default_logic_cmd14",8'h01,8'h01,4'd14,0,0,2'b11, 1, 0, 0, 0, 1);
        // TC100: Default logic CMD=15
        tc1(100,"default_logic_cmd15",8'h01,8'h01,4'd15,0,0,2'b11, 1, 0, 0, 0, 1);

        // TC101: MODE switch mid-stream — check ref model handles it
        begin
            reset;
            drive(8'h05,8'h03,4'd0,1,0,2'b11); wait_n(1);
            drive(8'h05,8'h03,4'd0,0,0,2'b11); wait_n(2);
            if (dut_res===ref_res)
                begin $display("PASS TC101 [mode_switch_mid] res=%0h",dut_res); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC101 [mode_switch_mid] DUT=%0h REF=%0h",dut_res,ref_res); fail_cnt=fail_cnt+1; end
        end

        // ------ TC102-118: CORNER CASES ----------------------------------------
        tc1(102,"add_ff_00",         8'hFF,8'h00,4'd0, 1,0,2'b11, 1, 0, 1, 0, 0);
        tc1(103,"add_cin_ff_00",     8'hFF,8'h00,4'd2, 1,1,2'b11, 1, 0, 1, 0, 0);
        tc1(104,"sub_01_01",         8'h01,8'h01,4'd1, 1,0,2'b11, 1, 1, 0, 0, 0);
        tc1(105,"inc_opa_ff",        8'hFF,8'h00,4'd4, 1,0,2'b01, 1, 0, 0, 0, 0);
        tc1(106,"dec_opa_01",        8'h01,8'h00,4'd5, 1,0,2'b01, 1, 0, 0, 0, 0);
        tc1(107,"inc_opb_ff",        8'h00,8'hFF,4'd6, 1,0,2'b10, 1, 0, 0, 0, 0);
        tc1(108,"dec_opb_00",        8'h00,8'h00,4'd7, 1,0,2'b10, 1, 0, 0, 0, 0);
        tc1(109,"cmp_max_zero",      8'hFF,8'h00,4'd8, 1,0,2'b11, 0, 0, 0, 1, 0);
        tc1(110,"cmp_zero_max",      8'h00,8'hFF,4'd8, 1,0,2'b11, 0, 0, 0, 1, 0);
        tc1(111,"sadd_zero_zero",    8'h00,8'h00,4'd11,1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(112,"ssub_min_min",      8'h80,8'h80,4'd12,1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(113,"rol_all_ones",      8'hFF,8'h05,4'd12,0,0,2'b11, 1, 0, 0, 0, 0);
        tc1(114,"sadd_pos",          8'h7F,8'hFF,4'd11,1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(115,"sadd_neg",          8'hD8,8'hFF,4'd11,1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(116,"ssub_pos_oflow",    8'h7F,8'hFF,4'd12,1,0,2'b11, 1, 1, 0, 1, 0);
        tc1(117,"ssub_neg",          8'hD8,8'h01,4'd12,1,0,2'b11, 1, 1, 0, 1, 0);
        tc_mul(118,"mul_max_2",      8'hFF,8'hFF,4'd9);

        // ── SUMMARY ──────────────────────────────────────────────────────────
        #20;
        $display("\n====================================================");
        $display("  TOTAL: %0d    PASS: %0d    FAIL: %0d",
                  pass_cnt+fail_cnt, pass_cnt, fail_cnt);
        $display("====================================================");
        $finish;
    end

    initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule

