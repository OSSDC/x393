/*******************************************************************************
 * Module: simul_clk
 * Date:2015-07-29  
 * Author: Andrey Filippov     
 * Description: Generate clocks for simulation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * simul_clk.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  simul_clk.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 *******************************************************************************/
`timescale 1ns/1ps

module  simul_clk#(
    parameter       CLKIN_PERIOD =  5.0,
    parameter       MEMCLK_PERIOD = 5.0,
    parameter       FCLK0_PERIOD = 10.417,
    parameter       FCLK1_PERIOD =  0.0
)(
    input        rst,
    output       clk,
    output       memclk,
    output [1:0] ffclk0,
    output [1:0] ffclk1
);
    
    wire ffclk0_w;
    wire ffclk1_w;
    assign ffclk0 = {~ffclk0_w,ffclk0_w};
    assign ffclk1 = {~ffclk1_w,ffclk1_w};
    generate
        if (CLKIN_PERIOD > 0.0)
            simul_clk_single #(.PERIOD(CLKIN_PERIOD)) simul_clk_i    (.rst(rst), .clk(clk));
        else
            assign clk = 0;
    endgenerate

    generate
        if (MEMCLK_PERIOD > 0.0)
            simul_clk_single #(.PERIOD(MEMCLK_PERIOD)) simul_memclk_i (.rst(rst), .clk(memclk));
        else
            assign memclk = 0;
    endgenerate

    generate
        if (FCLK0_PERIOD > 0.0)
            simul_clk_single #(.PERIOD(FCLK0_PERIOD)) simul_ffclk0_i (.rst(rst), .clk(ffclk0_w));
        else
            assign ffclk0_w = 0;
    endgenerate

    generate
        if (FCLK1_PERIOD > 0.0)
            simul_clk_single #(.PERIOD(FCLK1_PERIOD)) simul_ffclk1_i (.rst(rst), .clk(ffclk1_w));
        else
            assign ffclk1_w = 0;
    endgenerate

endmodule

module simul_clk_single #(
        parameter PERIOD = 1000.0
    ) (
        input rst,
        output clk
    );
    reg clk_r = 0;
    assign clk = clk_r;
    always #(PERIOD/2) clk_r <= rst ? 1'b0:  ~clk_r;
endmodule
