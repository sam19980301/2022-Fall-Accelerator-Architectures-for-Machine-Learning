`include "pe.v"

module Bitblade (
	in_a,
	in_b,
    out_c
);

// CFU interface
//      input bandwidth:		32 * 2 = 64 bits
//      output bandwidth:	    32 bits

//  summation of 4 8-bit inner product : a1 * b1 + a2 * b2 + a3 * b3 + a4 * b4 (in 8-bit format)
//      input bandwidth:    4 * 8 * 2 = 64 bits
//          format: 0x 0000 0000 aabb ccdd (a1 ~ a4)
//          format: 0x 0000 0000 eeff gghh (b1 ~ b4)

input   [31:0] in_a;
input   [31:0] in_b;
output  [17:0] out_c;

wire    [15:0] pe_in_a[3:0];
wire    [15:0] pe_in_b[3:0];
wire    [ 9:0] pe_out_c[3:0];

// 0x WXWX WXWX YZYZ YZYZ
wire	[31:0] a_top, a_bot;
wire	[31:0] b_top, b_bot;

assign a_top = {in_a[28+4-1:28], in_a[20+4-1:20], in_a[12+4-1:12], in_a[ 4+4-1: 4]};
assign a_bot = {in_a[24+4-1:24], in_a[16+4-1:16], in_a[ 8+4-1: 8], in_a[ 0+4-1: 0]};

assign b_top = {in_b[28+4-1:28], in_b[20+4-1:20], in_b[12+4-1:12], in_b[ 4+4-1: 4]};
assign b_bot = {in_b[24+4-1:24], in_b[16+4-1:16], in_b[ 8+4-1: 8], in_b[ 0+4-1: 0]};

assign pe_in_a[0] = a_top;
assign pe_in_a[1] = a_bot;
assign pe_in_a[2] = a_top;
assign pe_in_a[3] = a_bot;

assign pe_in_b[0] = b_top;
assign pe_in_b[1] = b_top;
assign pe_in_b[2] = b_bot;
assign pe_in_b[3] = b_bot;

PE pe0( .in_a(pe_in_a[0]), .in_b(pe_in_b[0]), .out_c(pe_out_c[0]));
PE pe1( .in_a(pe_in_a[1]), .in_b(pe_in_b[1]), .out_c(pe_out_c[1]));
PE pe2( .in_a(pe_in_a[2]), .in_b(pe_in_b[2]), .out_c(pe_out_c[2]));
PE pe3( .in_a(pe_in_a[3]), .in_b(pe_in_b[3]), .out_c(pe_out_c[3]));

assign out_c = (pe_out_c[0] << 8) + (pe_out_c[1] << 4) + (pe_out_c[2] << 4) + (pe_out_c[3] << 0);
endmodule