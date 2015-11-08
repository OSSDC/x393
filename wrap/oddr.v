/*******************************************************************************
 * Module: oddr
 * Date:2014-05-13  
 * Author: Andrey Filippov
 * Description: ODDR wrapper
 *
 * Copyright (c) 2014 Elphel, Inc.
 * oddr.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  oddr.v is distributed in the hope that it will be useful,
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

module  oddr#(
        parameter DDR_CLK_EDGE = "OPPOSITE_EDGE",
        parameter INIT          = 1'b0,
        parameter SRTYPE = "SYNC"
)(
    input  clk,
    input  ce,
    input  rst,
    input  set,
    input [1:0] din,
    output dq
);
    /* Instance template for module ODDR */
    ODDR #(
        .DDR_CLK_EDGE(DDR_CLK_EDGE),
        .INIT(INIT),
        .SRTYPE(SRTYPE)
    ) ODDR_i (
        .Q(dq), // output 
        .C(clk), // input 
        .CE(ce), // input 
        .D1(din[0]), // input 
        .D2(din[1]), // input 
        .R(rst), // input 
        .S(set) // input 
    );


endmodule

