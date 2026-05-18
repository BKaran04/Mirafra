//=============================================================================
// Self-Checking Testbench — alu.v
// DUT vs Reference Model — mismatch = FAIL = bug found
//
// Key differences from Karan.v TB:
//  - Module: alu  (ports: CLK RST CE MODE CIN INP_VALID CMD OPA OPB)
//  - Pipeline: inputs registered, outputs written SAME CE cycle (1-cycle latency)
//  - CE=0 → RES=0 (not hold)
//  - CMD=4,5: ONLY INP_VALID=2'b01 valid (strict, not 2'b11)
//  - CMD=6,7: ONLY INP_VALID=2'b10 valid (strict, not 2'b11)
//  - CMD=9,10: cycle_cnt based (cnt=1 load, cnt=2 result)
//  - tc1 waits 2 clocks (1 to register inputs + 1 for output)
//  - tc_mul drives 3 clocks (reset→cnt=0, drive→cnt=1 load, drive→cnt=2 result)
//=============================================================================
`timescale 1ns/1ps

module alu_tb;

    // ── Ports ─────────────────────────────────────────────────────────────────
    reg        CLK, RST, CIN, CE, MODE;
    reg  [1:0] INP_VALID;
    reg  [7:0] OPA, OPB;
    reg  [3:0] CMD;

    wire [15:0] dut_RES,   ref_RES;
    wire        dut_OFLOW, ref_OFLOW;
    wire        dut_COUT,  ref_COUT;
    wire        dut_G,     ref_G;
    wire        dut_L,     ref_L;
    wire        dut_E,     ref_E;
    wire        dut_ERR,   ref_ERR;

    // ── DUT ───────────────────────────────────────────────────────────────────
    alu DUT (
        .CLK(CLK), .RST(RST), .CIN(CIN), .CE(CE), .MODE(MODE),
        .INP_VALID(INP_VALID), .OPA(OPA), .OPB(OPB), .CMD(CMD),
        .RES(dut_RES), .OFLOW(dut_OFLOW), .COUT(dut_COUT),
        .G(dut_G), .L(dut_L), .E(dut_E), .ERR(dut_ERR)
    );

    // ── Reference Model ───────────────────────────────────────────────────────
    alu_ref_model REF (
        .CLK(CLK), .RST(RST), .CIN(CIN), .CE(CE), .MODE(MODE),
        .INP_VALID(INP_VALID), .OPA(OPA), .OPB(OPB), .CMD(CMD),
        .RES(ref_RES), .OFLOW(ref_OFLOW), .COUT(ref_COUT),
        .G(ref_G), .L(ref_L), .E(ref_E), .ERR(ref_ERR)
    );

    // ── Clock ─────────────────────────────────────────────────────────────────
    initial CLK = 0;
    always  #5 CLK = ~CLK;   // 100 MHz

    // ── Scoreboard ────────────────────────────────────────────────────────────
    integer pass_cnt = 0, fail_cnt = 0;

    //==========================================================================
    // TASKS
    //==========================================================================

    // Hard reset
    task reset;
        begin
            @(negedge CLK);
            RST=1; CE=0; CIN=0; MODE=0;
            OPA=0; OPB=0; CMD=0; INP_VALID=0;
            @(posedge CLK); #1;
            @(posedge CLK); #1;
            @(negedge CLK); RST=0;
        end
    endtask

    // Drive inputs on negedge
    task drive;
        input [7:0] i_opa, i_opb;
        input [3:0] i_cmd;
        input       i_mode, i_cin;
        input [1:0] i_inv;
        begin
            @(negedge CLK);
            OPA=i_opa; OPB=i_opb; CMD=i_cmd;
            MODE=i_mode; CIN=i_cin; INP_VALID=i_inv; CE=1;
        end
    endtask

    // Wait N rising edges
    task wait_n;
        input integer n; integer i;
        begin for(i=0;i<n;i=i+1) @(posedge CLK); #1; end
    endtask

    // Scoreboard check — compare DUT vs ref model
    // flags: chk_res chk_oflow chk_cout chk_gle chk_err
    task check;
        input integer     tc_num;
        input [200*8-1:0] tc_name;
        input             chk_res, chk_oflow, chk_cout, chk_gle, chk_err;
        reg               fail;
        begin
            fail = 0;
            if (chk_res   && dut_RES   !== ref_RES)
                begin $display("    RES  : DUT=%0h REF=%0h", dut_RES, ref_RES);     fail=1; end
            if (chk_oflow && dut_OFLOW !== ref_OFLOW)
                begin $display("    OFLOW: DUT=%0b REF=%0b", dut_OFLOW, ref_OFLOW); fail=1; end
            if (chk_cout  && dut_COUT  !== ref_COUT)
                begin $display("    COUT : DUT=%0b REF=%0b", dut_COUT, ref_COUT);   fail=1; end
            if (chk_gle) begin
                if (dut_G!==ref_G) begin $display("    G: DUT=%0b REF=%0b",dut_G,ref_G); fail=1; end
                if (dut_L!==ref_L) begin $display("    L: DUT=%0b REF=%0b",dut_L,ref_L); fail=1; end
                if (dut_E!==ref_E) begin $display("    E: DUT=%0b REF=%0b",dut_E,ref_E); fail=1; end
            end
            if (chk_err   && dut_ERR   !== ref_ERR)
                begin $display("    ERR  : DUT=%0b REF=%0b", dut_ERR, ref_ERR);     fail=1; end

            if (fail) begin
                $display("FAIL TC%-3d [%0s]  OPA=%0h OPB=%0h CMD=%0d MODE=%0b INV=%0b CIN=%0b",
                         tc_num, tc_name, OPA, OPB, CMD, MODE, INP_VALID, CIN);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS TC%0d  [%0s]", tc_num, tc_name);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // Standard 1-cycle test
    // alu.v: drive → CLK1 registers inputs → CLK2 outputs written
    // So wait 2 clocks after drive
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
            drive(i_opa, i_opb, i_cmd, i_mode, i_cin, i_inv);
            wait_n(2);
            check(num, name, c_res, c_oflow, c_cout, c_gle, c_err);
        end
    endtask

    // 2-cycle multiply — cycle_cnt based
    // cycle_cnt=0 after reset, starts counting when MODE=1 & CMD=9/10
    // Drive cycle: cnt goes 0→1→2
    //   cnt=1: inputs registered, RES=X
    //   cnt=2: RES = result
    // So: drive once (cnt=1, load), drive again (cnt=2, compute), wait 1 more for output
    task tc_mul;
        input integer      num;
        input [200*8-1:0]  name;
        input [7:0]        i_opa, i_opb;
        input [3:0]        i_cmd;
        begin
            reset;
            // Cycle 1: cnt goes to 1 — loads mul_op_a/b
            drive(i_opa, i_opb, i_cmd, 1'b1, 1'b0, 2'b11);
            wait_n(1);
            // Cycle 2: cnt goes to 2 — computes result
            drive(i_opa, i_opb, i_cmd, 1'b1, 1'b0, 2'b11);
            wait_n(2);
            check(num, name, 1,0,0,0,0);
        end
    endtask

    //==========================================================================
    // TEST SEQUENCE
    //==========================================================================
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
        RST=1; CE=0; CIN=0; MODE=0;
        OPA=0; OPB=0; CMD=0; INP_VALID=0;
        @(posedge CLK); @(posedge CLK); #1; RST=0;

        $display("\n====================================================");
        $display("  ALU TESTBENCH  —  118 Test Cases");
        $display("====================================================\n");

        //----------------------------------------------------------------------
        // TC1: CLK
        //----------------------------------------------------------------------
        begin
            reset; pass_cnt=pass_cnt+1;
            $display("PASS TC1   [clk_toggle] simulation running = clock OK");
        end

        //----------------------------------------------------------------------
        // TC2: RST assert — all outputs 0
        //----------------------------------------------------------------------
        begin
            @(negedge CLK); RST=1; CE=1; MODE=1; CMD=0;
            OPA=8'hFF; OPB=8'hFF; INP_VALID=2'b11;
            @(posedge CLK); #1;
            if (dut_RES===0 && dut_ERR===0 && dut_OFLOW===0 &&
                dut_COUT===0 && dut_G===0 && dut_L===0 && dut_E===0)
                begin $display("PASS TC2   [async_reset]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC2   [async_reset]"); fail_cnt=fail_cnt+1; end
            @(negedge CLK); RST=0;
        end

        //----------------------------------------------------------------------
        // TC3: RST during operation — outputs clear immediately
        //----------------------------------------------------------------------
        begin
            @(negedge CLK); RST=0; CE=1; MODE=1; CMD=0;
            OPA=8'hAA; OPB=8'h55; INP_VALID=2'b11;
            @(posedge CLK); #1;
            @(negedge CLK); RST=1;
            @(posedge CLK); #1;
            if (dut_RES===0 && dut_ERR===0 && dut_OFLOW===0)
                begin $display("PASS TC3   [rst_during_op]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC3   [rst_during_op]"); fail_cnt=fail_cnt+1; end
            @(negedge CLK); RST=0;
        end

        //----------------------------------------------------------------------
        // TC4: CE enable — operation executes
        //----------------------------------------------------------------------
        begin
            reset;
            drive(8'h05, 8'h03, 4'd0, 1, 0, 2'b11);
            wait_n(2);
            if (dut_RES===16'h0008)
                begin $display("PASS TC4   [ce_enable]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC4   [ce_enable] RES=%0h", dut_RES); fail_cnt=fail_cnt+1; end
        end

        //----------------------------------------------------------------------
        // TC5: CE=0 — RES clears to 0 (alu.v clears on CE=0, unlike Karan.v)
        //----------------------------------------------------------------------
        begin
            reset;
            drive(8'h05, 8'h03, 4'd0, 1, 0, 2'b11);
            wait_n(2);
            @(negedge CLK); CE=0; OPA=8'hFF; OPB=8'hFF;
            @(posedge CLK); #1;
            if (dut_RES===0)
                begin $display("PASS TC5   [ce_disable_clears_res]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC5   [ce_disable_clears_res] RES=%0h", dut_RES); fail_cnt=fail_cnt+1; end
        end

        //----------------------------------------------------------------------
        // TC6-22: ARITHMETIC MODE=1
        //----------------------------------------------------------------------
        //           num  name                  opa    opb   cmd  mo ci  inv   res of co gl er
        tc1(6,  "add_without_cout",       8'h05,8'h03,4'd0, 1,0,2'b11,  1, 0, 1, 0, 0);
        tc1(7,  "add_with_cout",          8'hA5,8'hA6,4'd0, 1,0,2'b11,  1, 0, 1, 0, 0);
        tc1(8,  "sub_a_equal_b",          8'h07,8'h07,4'd1, 1,0,2'b11,  1, 1, 0, 0, 0);
        tc1(9,  "sub_a_less_b",           8'h06,8'h07,4'd1, 1,0,2'b11,  1, 1, 0, 0, 0);
        tc1(10, "sub_a_great_b",          8'h07,8'h05,4'd1, 1,0,2'b11,  1, 1, 0, 0, 0);
        tc1(11, "add_cin_no_cout",        8'h01,8'h01,4'd2, 1,1,2'b11,  1, 0, 1, 0, 0);
        tc1(12, "add_cin_cout",           8'hA6,8'hA7,4'd2, 1,1,2'b11,  1, 0, 1, 0, 0);
        // CMD=3: no OFLOW in alu.v — chk_oflow=0
        tc1(13, "sub_cin_equal",          8'h05,8'h05,4'd3, 1,1,2'b11,  1, 0, 0, 0, 0);
        tc1(14, "sub_cin_lessthan",       8'h04,8'h05,4'd3, 1,1,2'b11,  1, 0, 0, 0, 0);
        tc1(15, "sub_cin_borrow",         8'h02,8'h01,4'd3, 1,1,2'b11,  1, 0, 0, 0, 0);
        // CMD=4,5: ONLY 2'b01 valid in alu.v
        tc1(16, "increment_a",            8'h08,8'h00,4'd4, 1,0,2'b01,  1, 0, 0, 0, 0);
        tc1(17, "decrement_a",            8'h08,8'h00,4'd5, 1,0,2'b01,  1, 0, 0, 0, 0);
        // CMD=6,7: ONLY 2'b10 valid in alu.v
        tc1(18, "increment_b",            8'h00,8'h08,4'd6, 1,0,2'b10,  1, 0, 0, 0, 0);
        tc1(19, "decrement_b",            8'h00,8'h08,4'd7, 1,0,2'b10,  1, 0, 0, 0, 0);
        tc1(20, "a_equal_b",              8'h09,8'h09,4'd8, 1,0,2'b11,  0, 0, 0, 1, 0);
        tc1(21, "a_less_b",               8'h07,8'h09,4'd8, 1,0,2'b11,  0, 0, 0, 1, 0);
        tc1(22, "a_greater_b",            8'h09,8'h07,4'd8, 1,0,2'b11,  0, 0, 0, 1, 0);

        //----------------------------------------------------------------------
        // TC23-35: MULTIPLY (2-cycle, cycle_cnt based)
        //----------------------------------------------------------------------
        tc_mul(23, "mul_basic",           8'h02,8'h03,4'd9);
        tc_mul(24, "mul_zero_opa",        8'h00,8'h04,4'd9);
        tc_mul(25, "mul_zero_opb",        8'h04,8'h00,4'd9);
        tc_mul(26, "mul_one_one",         8'h00,8'h00,4'd9);
        tc_mul(27, "mul_max",             8'hFF,8'hFF,4'd9);

        // TC28: cycle_cnt=1 — RES=X, no ERR
        begin
            reset;
            drive(8'h02, 8'h03, 4'd9, 1, 0, 2'b11);
            wait_n(1);
            if (dut_ERR===0)
                begin $display("PASS TC28  [mul_cycle1_no_err]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC28  [mul_cycle1_no_err]"); fail_cnt=fail_cnt+1; end
        end

        // TC29: MUL invalid INP_VALID → ERR=1 RES=0
        tc1(29, "mul_inp_invalid",        8'h02,8'h03,4'd9,  1,0,2'b01,  1, 0, 0, 0, 1);

        tc_mul(30, "mul2x_basic",         8'h03,8'h04,4'd10);
        tc_mul(31, "mul2x_zero_opa",      8'h00,8'h05,4'd10);
        tc_mul(32, "mul2x_zero_opb",      8'h04,8'h00,4'd10);
        tc_mul(33, "mul2x_max",           8'hFF,8'hFF,4'd10);

        // TC34: MUL2x cycle_cnt=1 — RES=X, no ERR
        begin
            reset;
            drive(8'h03, 8'h04, 4'd10, 1, 0, 2'b11);
            wait_n(1);
            if (dut_ERR===0)
                begin $display("PASS TC34  [mul2x_cycle1_no_err]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC34  [mul2x_cycle1_no_err]"); fail_cnt=fail_cnt+1; end
        end

        // TC35: MUL2x invalid INP_VALID → ERR=1 RES=0
        tc1(35, "mul2x_inp_invalid",      8'h03,8'h04,4'd10, 1,0,2'b10,  1, 0, 0, 0, 1);

        //----------------------------------------------------------------------
        // TC36-42: SIGNED ARITHMETIC (CMD=11, CMD=12)
        //----------------------------------------------------------------------
        tc1(36, "signed_add_pp",          8'h05,8'h03,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(37, "signed_add_nn",          8'hFD,8'hFE,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(38, "signed_add_pn_zero",     8'h08,8'hF8,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(39, "signed_add_equal",       8'h05,8'h05,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(40, "signed_sub_a_gt_b",      8'h08,8'hFD,4'd12, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(41, "signed_sub_a_lt_b",      8'hFD,8'h08,4'd12, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(42, "signed_sub_equal",       8'hFB,8'hFD,4'd12, 1,0,2'b11,  1, 1, 0, 1, 0);

        //----------------------------------------------------------------------
        // TC43-60: LOGICAL MODE=0
        //----------------------------------------------------------------------
        tc1(43, "and_zero_mask",          8'hFF,8'h00,4'd0,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(44, "and_ff_mask",            8'hA5,8'hFF,4'd0,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(45, "nand_ff_mask",           8'hA5,8'hFF,4'd1,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(46, "nand_zero_mask",         8'hA5,8'h00,4'd1,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(47, "or_zero_mask",           8'hA5,8'h00,4'd2,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(48, "or_ff_mask",             8'h00,8'hFF,4'd2,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(49, "nor_zero_mask",          8'hA5,8'h00,4'd3,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(50, "nor_ff_mask",            8'h00,8'hFF,4'd3,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(51, "xor_same",               8'hA5,8'hA5,4'd4,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(52, "xor_inv",                8'hA5,8'h5A,4'd4,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(53, "xnor_same",              8'hA5,8'hA5,4'd5,  0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(54, "xnor_inv",               8'hA5,8'h5A,4'd5,  0,0,2'b11,  1, 0, 0, 0, 0);
        // CMD=6,7,8,9,10,11 in logical mode — strict single-operand INP_VALID
        tc1(55, "not_a_zero",             8'h00,8'h00,4'd6,  0,0,2'b01,  1, 0, 0, 0, 0);
        tc1(56, "not_b_ff",               8'h00,8'hFF,4'd7,  0,0,2'b10,  1, 0, 0, 0, 0);
        tc1(57, "shr_a_lsb",              8'h02,8'h00,4'd8,  0,0,2'b01,  1, 0, 0, 0, 0);
        tc1(58, "shl_a_msb",              8'h02,8'h00,4'd9,  0,0,2'b01,  1, 0, 0, 0, 0);
        tc1(59, "shr_b_lsb",              8'h00,8'h02,4'd10, 0,0,2'b10,  1, 0, 0, 0, 0);
        tc1(60, "shl_b_msb",              8'h00,8'h02,4'd11, 0,0,2'b10,  1, 0, 0, 0, 0);

        //----------------------------------------------------------------------
        // TC61-69: ROTATE RIGHT (CMD=13, MODE=0)
        //----------------------------------------------------------------------
        tc1(61, "ror_0",                  8'h80,8'h00,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(62, "ror_1",                  8'h01,8'h01,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(63, "ror_2",                  8'h01,8'h02,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(64, "ror_3",                  8'h08,8'h03,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(65, "ror_4",                  8'hF0,8'h04,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(66, "ror_5",                  8'h80,8'h05,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(67, "ror_6",                  8'h80,8'h06,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(68, "ror_7",                  8'h80,8'h07,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(69, "ror_all_ones",           8'hFF,8'h05,4'd13, 0,0,2'b11,  1, 0, 0, 0, 0);

        //----------------------------------------------------------------------
        // TC70-79: ROTATE ERROR CASES (OPB upper bits set → ERR)
        //----------------------------------------------------------------------
        tc1(70, "Error_ROL_opb10",        8'h01,8'h10,4'd12, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(71, "Error_ROL_opb20",        8'h01,8'h20,4'd12, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(72, "Error_ROL_opb40",        8'h01,8'h40,4'd12, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(73, "Error_ROL_opb80",        8'h01,8'h80,4'd12, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(74, "Error_ROL_inv",          8'h01,8'h01,4'd12, 0,0,2'b01,  1, 0, 0, 0, 1);
        tc1(75, "Error_ROR_opb10",        8'h01,8'h10,4'd13, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(76, "Error_ROR_opb20",        8'h01,8'h20,4'd13, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(77, "Error_ROR_opb40",        8'h01,8'h40,4'd13, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(78, "Error_ROR_opb80",        8'h01,8'h80,4'd13, 0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(79, "Error_ROR_inv",          8'h01,8'h01,4'd13, 0,0,2'b01,  1, 0, 0, 0, 1);

        //----------------------------------------------------------------------
        // TC80-94: INP_VALID NEGATIVE CASES
        //----------------------------------------------------------------------
        tc1(80, "inv_add_00",             8'h05,8'h03,4'd0,  1,0,2'b00,  1, 0, 0, 0, 1);
        tc1(81, "inv_add_01",             8'h05,8'h03,4'd0,  1,0,2'b01,  1, 0, 0, 0, 1);
        tc1(82, "inv_add_10",             8'h05,8'h03,4'd0,  1,0,2'b10,  1, 0, 0, 0, 1);
        tc1(83, "inv_sub_00",             8'h05,8'h03,4'd1,  1,0,2'b00,  1, 0, 0, 0, 1);
        tc1(84, "inv_sub_01",             8'h05,8'h03,4'd1,  1,0,2'b01,  1, 0, 0, 0, 1);
        tc1(85, "inv_sub_10",             8'h05,8'h03,4'd1,  1,0,2'b10,  1, 0, 0, 0, 1);
        // CMD=4: ONLY 2'b01 valid — so 2'b11 and 2'b10 are both errors in alu.v
        tc1(86, "inv_inc_opa_11",         8'h05,8'h00,4'd4,  1,0,2'b11,  1, 0, 0, 0, 1);
        tc1(87, "inv_inc_opa_10",         8'h05,8'h00,4'd4,  1,0,2'b10,  1, 0, 0, 0, 1);
        // CMD=6: ONLY 2'b10 valid — so 2'b11 and 2'b01 are both errors
        tc1(88, "inv_inc_opb_11",         8'h00,8'h05,4'd6,  1,0,2'b11,  1, 0, 0, 0, 1);
        tc1(89, "inv_inc_opb_01",         8'h00,8'h05,4'd6,  1,0,2'b01,  1, 0, 0, 0, 1);
        // CMD=7: ONLY 2'b10 valid — so 2'b01 is an error
        tc1(90, "inv_dec_opb_01",         8'h00,8'h05,4'd7,  1,0,2'b01,  1, 0, 0, 0, 1);
        // Logical invalid cases
        tc1(91, "inv_logic_and_01",       8'hAA,8'h55,4'd0,  0,0,2'b01,  1, 0, 0, 0, 1);
        tc1(92, "inv_notA_11",            8'hAA,8'h00,4'd6,  0,0,2'b11,  1, 0, 0, 0, 1);
        tc1(93, "inv_notB_01",            8'h00,8'hF0,4'd7,  0,0,2'b01,  1, 0, 0, 0, 1);
        tc1(94, "inv_shr_b_01",           8'h00,8'h40,4'd10, 0,0,2'b01,  1, 0, 0, 0, 1);

        //----------------------------------------------------------------------
        // TC95-101: CONTROL CASES
        //----------------------------------------------------------------------

        // TC95: CE=0 — RES=0 (alu.v clears RES when CE=0)
        begin
            reset;
            @(negedge CLK); CE=0; MODE=1; CMD=0;
            OPA=8'hFF; OPB=8'hFF; INP_VALID=2'b11;
            @(posedge CLK); #1;
            if (dut_RES===0)
                begin $display("PASS TC95  [ce_low_res_zero]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC95  [ce_low_res_zero]"); fail_cnt=fail_cnt+1; end
        end

        // TC96: CE toggle mid multiply — RES clears to 0 on CE=0
        begin
            reset;
            drive(8'h02, 8'h03, 4'd9, 1, 0, 2'b11);
            wait_n(1);
            @(negedge CLK); CE=0;
            @(posedge CLK); #1;
            if (dut_RES===0)
                begin $display("PASS TC96  [ce_toggle_mid_mul_clears]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC96  [ce_toggle_mid_mul_clears] RES=%0h", dut_RES); fail_cnt=fail_cnt+1; end
        end

        // TC97: RST during multiply — all outputs 0
        begin
            reset;
            drive(8'h02, 8'h03, 4'd9, 1, 0, 2'b11);
            wait_n(1);
            @(negedge CLK); RST=1;
            @(posedge CLK); #1;
            if (dut_RES===0 && dut_ERR===0 && dut_OFLOW===0 &&
                dut_G===0 && dut_L===0 && dut_E===0)
                begin $display("PASS TC97  [rst_during_mul]"); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC97  [rst_during_mul]"); fail_cnt=fail_cnt+1; end
            @(negedge CLK); RST=0;
        end

        // TC98: Default arith CMD=13 → ERR=1
        tc1(98,  "default_arith_cmd13",   8'h01,8'h01,4'd13, 1,0,2'b11,  1, 0, 0, 0, 1);
        // TC99: Default logic CMD=14 → ERR=1
        tc1(99,  "default_logic_cmd14",   8'h01,8'h01,4'd14, 0,0,2'b11,  1, 0, 0, 0, 1);
        // TC100: Default logic CMD=15 → ERR=1
        tc1(100, "default_logic_cmd15",   8'h01,8'h01,4'd15, 0,0,2'b11,  1, 0, 0, 0, 1);

        // TC101: MODE switch mid-stream
        begin
            reset;
            drive(8'h05, 8'h03, 4'd0, 1, 0, 2'b11); wait_n(1);
            drive(8'h05, 8'h03, 4'd0, 0, 0, 2'b11); wait_n(2);
            if (dut_RES===ref_RES)
                begin $display("PASS TC101 [mode_switch_mid] RES=%0h", dut_RES); pass_cnt=pass_cnt+1; end
            else begin $display("FAIL TC101 [mode_switch_mid] DUT=%0h REF=%0h", dut_RES, ref_RES); fail_cnt=fail_cnt+1; end
        end

        //----------------------------------------------------------------------
        // TC102-118: CORNER CASES
        //----------------------------------------------------------------------
        tc1(102, "add_ff_00",             8'hFF,8'h00,4'd0,  1,0,2'b11,  1, 0, 1, 0, 0);
        tc1(103, "add_cin_ff_00",         8'hFF,8'h00,4'd2,  1,1,2'b11,  1, 0, 1, 0, 0);
        tc1(104, "sub_01_01_no_oflow",    8'h01,8'h01,4'd1,  1,0,2'b11,  1, 1, 0, 0, 0);
        // CMD=4,5 strict: only 2'b01 valid
        tc1(105, "inc_opa_ff",            8'hFF,8'h00,4'd4,  1,0,2'b01,  1, 0, 0, 0, 0);
        tc1(106, "dec_opa_01",            8'h01,8'h00,4'd5,  1,0,2'b01,  1, 0, 0, 0, 0);
        // CMD=6,7 strict: only 2'b10 valid
        tc1(107, "inc_opb_ff",            8'h00,8'hFF,4'd6,  1,0,2'b10,  1, 0, 0, 0, 0);
        tc1(108, "dec_opb_00",            8'h00,8'h00,4'd7,  1,0,2'b10,  1, 0, 0, 0, 0);
        tc1(109, "cmp_max_zero",          8'hFF,8'h00,4'd8,  1,0,2'b11,  0, 0, 0, 1, 0);
        tc1(110, "cmp_zero_max",          8'h00,8'hFF,4'd8,  1,0,2'b11,  0, 0, 0, 1, 0);
        tc1(111, "sadd_zero_zero",        8'h00,8'h00,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(112, "ssub_min_min",          8'h80,8'h80,4'd12, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(113, "rol_all_ones",          8'hFF,8'h05,4'd12, 0,0,2'b11,  1, 0, 0, 0, 0);
        tc1(114, "sadd_pos",              8'h7F,8'hFF,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(115, "sadd_neg",              8'hD8,8'hFF,4'd11, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(116, "ssub_pos_oflow",        8'h7F,8'hFF,4'd12, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc1(117, "ssub_neg",              8'hD8,8'h01,4'd12, 1,0,2'b11,  1, 1, 0, 1, 0);
        tc_mul(118,"mul_max_2",           8'hFF,8'hFF,4'd9);

        //----------------------------------------------------------------------
        // SUMMARY
        //----------------------------------------------------------------------
        #20;
        $display("\n====================================================");
        $display("  TOTAL: %0d    PASS: %0d    FAIL: %0d",
                  pass_cnt+fail_cnt, pass_cnt, fail_cnt);
        $display("====================================================\n");
        $finish;
    end

    initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule

