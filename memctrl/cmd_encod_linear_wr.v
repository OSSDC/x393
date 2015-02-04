/*******************************************************************************
 * Module: cmd_encod_linear_wr
 * Date:2015-01-23  
 * Author: andrey     
 * Description: Command sequencer generator for writing a sequential  up to 1KB page
 * single page access, bank and row will not be changed
 *
 * Copyright (c) 2015 <set up in Preferences-Verilog/VHDL Editor-Templates> .
 * cmd_encod_linear_wr.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  cmd_encod_linear_wr.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  cmd_encod_linear_wr #(
//    parameter BASEADDR = 0,
    parameter ADDRESS_NUMBER=       15,
    parameter COLADDR_NUMBER=       10,
    parameter CMD_PAUSE_BITS=       10,
    parameter CMD_DONE_BIT=         10 // VDT BUG: CMD_DONE_BIT is used in a function call parameter!
) (
    input                        rst,
    input                        clk,
// programming interface
//    input                  [7:0] cmd_ad,      // byte-serial command address/data (up to 6 bytes: AL-AH-D0-D1-D2-D3 
//    input                        cmd_stb,     // strobe (with first byte) for the command a/d
    input                  [2:0] bank_in,     // bank address
    input   [ADDRESS_NUMBER-1:0] row_in,      // memory row
    input   [COLADDR_NUMBER-4:0] start_col,   // start memory column (3 LSBs should be 0?)
    input                  [5:0] num128_in,   // number of 128-bit words to transfer (8*16 bits) - full burst of 8
    input                        start,       // start generating commands
    output reg            [31:0] enc_cmd,     // encoded commnad
    output reg                   enc_wr,      // write encoded command
    output reg                   enc_done     // encoding finished
);
    localparam ROM_WIDTH=11;
    localparam ROM_DEPTH=4;
    
    localparam ENC_NOP=        0;
    localparam ENC_BUF_RD=     1;
    localparam ENC_DQS_TOGGLE= 2;
    localparam ENC_DQ_DQS_EN=  3;
    localparam ENC_SEL=        4;
    localparam ENC_ODT=        5;
    localparam ENC_CMD_SHIFT=  6; // [7:6] - command: 0 -= NOP, 1 - WRITE, 2 - PRECHARGE, 3 - ACTIVATE
    localparam ENC_PAUSE_SHIFT=8; // [9:8] - 2- bit pause (for NOP commandes)
    localparam ENC_PRE_DONE=  10;
    
    localparam ENC_CMD_NOP=      0; // 2-bit locally encoded commands
    localparam ENC_CMD_WRITE=    1;
    localparam ENC_CMD_PRECHARGE=2;
    localparam ENC_CMD_ACTIVATE= 3;
    localparam REPEAT_ADDR=4;
    
    localparam CMD_NOP=      0; // 3-bit normal memory RCW commands (positive logic)
    localparam CMD_WRITE=    3;
    localparam CMD_PRECHARGE=5;
    localparam CMD_ACTIVATE= 4;
    
    reg   [ADDRESS_NUMBER-1:0] row;     // memory row
    reg   [COLADDR_NUMBER-4:0] col;     // start memory column (3 LSBs should be 0?) // VDT BUG: col is used as a function call parameter!
    reg                  [2:0] bank;    // memory bank;
    reg                  [5:0] num128;  // number of 128-bit words to transfer
    
    reg                        gen_run;
    reg                        gen_run_d;
    reg        [ROM_DEPTH-1:0] gen_addr; // will overrun as stop comes from ROM
    
    reg        [ROM_WIDTH-1:0] rom_r; 
    wire                       pre_done;
    wire                 [1:0] rom_cmd;
    wire                 [1:0] rom_skip;
    wire                 [2:0] full_cmd;
    reg                        done;

    assign     pre_done=rom_r[ENC_PRE_DONE] && gen_run;
    assign     rom_cmd=  rom_r[ENC_CMD_SHIFT+:2];
    assign     rom_skip= rom_r[ENC_PAUSE_SHIFT+:2];
    assign     full_cmd= rom_cmd[1]?(rom_cmd[0]?CMD_ACTIVATE:CMD_PRECHARGE):(rom_cmd[0]?CMD_WRITE:CMD_NOP);
    
    always @ (posedge rst or posedge clk) begin
        if (rst)           gen_run <= 0;
        else if (start)    gen_run<= 1;
        else if (pre_done) gen_run<= 0;
        
        if (rst)           gen_run_d <= 0;
        else               gen_run_d <= gen_run;

        if (rst)                     gen_addr <= 0;
        else if (!start && !gen_run) gen_addr <= 0;
        else if ((gen_addr==(REPEAT_ADDR-1)) && (num128[5:1]==0)) gen_addr <= REPEAT_ADDR+1; // skip loop alltogeter
        else if ((gen_addr !=REPEAT_ADDR) || (num128[5:1]==0)) gen_addr <= gen_addr+1; // not in a loop

//counting loops        
        if      (rst)        num128 <= 0;
        else if (start)      num128 <= num128_in;
        else if (!gen_run)   num128 <= 0; //
        else if ((gen_addr == (REPEAT_ADDR-1)) || (gen_addr == REPEAT_ADDR))  num128 <= num128 -1;
    end
    
    always @ (posedge clk) if (start) begin
        row<=row_in;
        col <= start_col;
        bank <= bank_in;
    end
    
    // ROM-based (registered output) encoded sequence
    always @ (posedge rst or posedge clk) begin
        if (rst)           rom_r <= 0;
        else case (gen_addr)
            4'h0: rom_r <= (ENC_CMD_ACTIVATE <<  ENC_CMD_SHIFT) | (1 << ENC_NOP); 
            4'h1: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (1 << ENC_BUF_RD); 
            4'h2: rom_r <= (ENC_CMD_WRITE <<     ENC_CMD_SHIFT) | (1 << ENC_BUF_RD) |(1 << ENC_SEL)         | (1 << ENC_ODT); 
            4'h3: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (1 << ENC_BUF_RD) |(1 << ENC_DQ_DQS_EN)   | (1 << ENC_ODT);
            4'h4: rom_r <= (ENC_CMD_WRITE <<     ENC_CMD_SHIFT) | (1 << ENC_NOP) | (1 << ENC_BUF_RD) | (1 << ENC_DQS_TOGGLE)  | (1 << ENC_DQ_DQS_EN)  | (1 << ENC_ODT); // will repeet 
            4'h5: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (2 << ENC_PAUSE_SHIFT) | (1 << ENC_DQS_TOGGLE) | (1 << ENC_DQ_DQS_EN) | (1 << ENC_ODT);
            4'h6: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (2 << ENC_PAUSE_SHIFT);
            4'h7: rom_r <= (ENC_CMD_PRECHARGE << ENC_CMD_SHIFT);
            4'h8: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (2 << ENC_PAUSE_SHIFT);
            4'h9: rom_r <= (ENC_CMD_NOP <<       ENC_CMD_SHIFT) | (1 << ENC_PRE_DONE);
            default:rom_r <= 0;
       endcase
    end
    always @ (posedge rst or posedge clk) begin
        if (rst)           done <= 0;
        else               done <= pre_done;
        
        if (rst)           enc_wr <= 0;
        else               enc_wr <= gen_run || gen_run_d;
        
        if (rst)           enc_done <= 0;
        else               enc_done <= enc_wr || !gen_run_d;
        
        if (rst)             enc_cmd <= 0;
        else if (rom_cmd==0) enc_cmd <= func_encode_skip ( // encode pause
            {{CMD_PAUSE_BITS-2{1'b0}},rom_skip[1:0]}, // skip;   // number of extra cycles to skip (and keep all the other outputs)
            done,                                     // end of sequence 
            bank[2:0],                                // bank (here OK to be any)
            rom_r[ENC_ODT],          //   odt_en;     // enable ODT
            1'b0,                    //   cke;        // disable CKE
            rom_r[ENC_SEL],          //   sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            rom_r[ENC_DQ_DQS_EN],    //   dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            rom_r[ENC_DQ_DQS_EN],    //   dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
            rom_r[ENC_DQS_TOGGLE],   //   dqs_toggle; // enable toggle DQS according to the pattern
            1'b0,                    //   dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            1'b0,                    //   buf_wr;     // connect to external buffer (but only if not paused)
            rom_r[ENC_BUF_RD]);      //   buf_rd;     // connect to external buffer (but only if not paused)
       else  enc_cmd <= func_encode_cmd ( // encode non-NOP command
            rom_cmd[1]?
                    row:
                    {{ADDRESS_NUMBER-COLADDR_NUMBER{1'b0}},col[COLADDR_NUMBER-4:0],3'b0}, //  [14:0] addr;       // 15-bit row/column adderss
            bank[2:0],                                // bank (here OK to be any)
            full_cmd[2:0],           //   rcw;        // RAS/CAS/WE, positive logic
            rom_r[ENC_ODT],          //   odt_en;     // enable ODT
            1'b0,                    //   cke;        // disable CKE
            rom_r[ENC_SEL],          //   sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            rom_r[ENC_DQ_DQS_EN],    //   dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            rom_r[ENC_DQ_DQS_EN],    //   dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
            rom_r[ENC_DQS_TOGGLE],   //   dqs_toggle; // enable toggle DQS according to the pattern
            1'b0,                    //   dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            1'b0,                    //   buf_wr;     // connect to external buffer (but only if not paused)
            rom_r[ENC_BUF_RD],       //   buf_rd;     // connect to external buffer (but only if not paused)     
            rom_r[ENC_NOP]);         //   nop;        // add NOP after the current command, keep other data
        
    end    
    

// move to include?

    function [31:0] func_encode_skip;
        input [CMD_PAUSE_BITS-1:0] skip;       // number of extra cycles to skip (and keep all the other outputs)
        input                      done;       // end of sequence 
        input [2:0]                bank;       // bank (here OK to be any)
        input                      odt_en;     // enable ODT
        input                      cke;        // disable CKE
        input                      sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
        input                      dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_toggle; // enable toggle DQS according to the pattern
        input                      dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
        input                      buf_wr;     // connect to external buffer (but only if not paused)
        input                      buf_rd;     // connect to external buffer (but only if not paused)
        begin
            func_encode_skip= func_encode_cmd (
                {{14-CMD_DONE_BIT{1'b0}}, done, skip[CMD_PAUSE_BITS-1:0]},       // 15-bit row/column adderss
                bank[2:0],  // bank (here OK to be any)
                3'b0,       // RAS/CAS/WE, positive logic
                odt_en,     // enable ODT
                cke,        // disable CKE
                sel,        // first/second half-cycle, other will be nop (cke+odt applicable to both)
                dq_en,      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
                dqs_en,     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
                dqs_toggle, // enable toggle DQS according to the pattern
                dci,        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
                buf_wr,     // connect to external buffer (but only if not paused)
                buf_rd,     // connect to external buffer (but only if not paused)
                1'b0);
        end
    endfunction

    function [31:0] func_encode_cmd;
        input               [14:0] addr;       // 15-bit row/column adderss
        input                [2:0] bank;       // bank (here OK to be any)
        input                [2:0] rcw;        // RAS/CAS/WE, positive logic
        input                      odt_en;     // enable ODT
        input                      cke;        // disable CKE
        input                      sel;        // first/second half-cycle, other will be nop (cke+odt applicable to both)
        input                      dq_en;      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_en;     // enable (not tristate) DQS lines (internal timing sequencer for 0->1 and 1->0)
        input                      dqs_toggle; // enable toggle DQS according to the pattern
        input                      dci;        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
        input                      buf_wr;     // connect to external buffer (but only if not paused)
        input                      buf_rd;     // connect to external buffer (but only if not paused)
        input                      nop;        // add NOP after the current command, keep other data
        begin
            func_encode_cmd={
            addr[14:0], // 15-bit row/column adderss
            bank [2:0], // bank
            rcw[2:0],   // RAS/CAS/WE
            odt_en,     // enable ODT
            cke,        // may be optimized (removed from here)?
            sel,        // first/second half-cycle, other will be nop (cke+odt applicable to both)
            dq_en,      // enable (not tristate) DQ  lines (internal timing sequencer for 0->1 and 1->0)
            dqs_en,     // enable (not tristate) DQS  lines (internal timing sequencer for 0->1 and 1->0)
            dqs_toggle, // enable toggle DQS according to the pattern
            dci,        // DCI disable, both DQ and DQS lines (internal logic and timing sequencer for 0->1 and 1->0)
            buf_wr,     // phy_buf_wr,   // connect to external buffer (but only if not paused)
            buf_rd,     // phy_buf_rd,    // connect to external buffer (but only if not paused)
            nop,        // add NOP after the current command, keep other data
            1'b0        // Reserved for future use
           };
        end
    endfunction

endmodule
