`include "pe.v"

module Bitblade (
	mode,
	in_a,
	in_b,
    out_c
);

// CFU interface
//      input bandwidth:		32 * 2 = 64 bits
//      output bandwidth:	    32 bits

// mode 0:  summation of 4 8-bit inner product : a1 * b1 + a2 * b2 + a3 * b3 + a4 * b4 (in 8-bit format)
//      input bandwidth:    4 * 8 * 2 = 64 bits
// 		    format: 0x 0000 0000 aabb ccdd (a1 ~ a4)
//          format: 0x 0000 0000 eeff gghh (b1 ~ b4)
//      output bandwidth:   8 + 8 * log(4) = 18 bits

// mode 1:  summation of 16 4-bit inner product : a1 * b1 + a2 * b2 + ... + a16 * b16 (in 4-bit format)
//      input bandwidth:    16 * 4 * 2 = 128 bits
// 		    format: 0x abcd efgh ijkl mnop (a1 ~ a16)
// 		    format: 0x qrst uvwx yzAB CDEF (b1 ~ b16)
//      output bandwidth:   4 + 4 * log(16) = 12 bits

// bitblade
//      input bandwidth:    max(64, 128) = 128
//      output bandwidth:   max(18, 12) = 18

input	mode;
input   [63:0] in_a;
input   [63:0] in_b;
output  [17:0] out_c;

// wire    [15:0] pe_in_a[3:0];
// wire    [15:0] pe_in_b[3:0];
// wire    [ 9:0] pe_out_c[3:0];

// assign pe_in_a[0] = {in_a[28+4-1:28], in_a[20+4-1:20], in_a[12+4-1:12], in_a[ 4+4-1: 4]}; // right top a
// assign pe_in_a[1] = {in_a[24+4-1:24], in_a[16+4-1:16], in_a[ 8+4-1: 8], in_a[ 0+4-1: 0]}; // right bot a
// assign pe_in_a[2] = {in_a[28+4-1:28], in_a[20+4-1:20], in_a[12+4-1:12], in_a[ 4+4-1: 4]}; // right top a
// assign pe_in_a[3] = {in_a[24+4-1:24], in_a[16+4-1:16], in_a[ 8+4-1: 8], in_a[ 0+4-1: 0]}; // right bot a

// assign pe_in_b[0] = {in_b[28+4-1:28], in_b[20+4-1:20], in_b[12+4-1:12], in_b[ 4+4-1: 4]}; // right top b
// assign pe_in_b[1] = {in_b[28+4-1:28], in_b[20+4-1:20], in_b[12+4-1:12], in_b[ 4+4-1: 4]}; // right top b
// assign pe_in_b[2] = {in_b[24+4-1:24], in_b[16+4-1:16], in_b[ 8+4-1: 8], in_b[ 0+4-1: 0]}; // right bot b
// assign pe_in_b[3] = {in_b[24+4-1:24], in_b[16+4-1:16], in_b[ 8+4-1: 8], in_b[ 0+4-1: 0]}; // right bot b

// PE pe0( .in_a(pe_in_a[0]), .in_b(pe_in_b[0]), .out_c(pe_out_c[0]));
// PE pe1( .in_a(pe_in_a[1]), .in_b(pe_in_b[1]), .out_c(pe_out_c[1]));
// PE pe2( .in_a(pe_in_a[2]), .in_b(pe_in_b[2]), .out_c(pe_out_c[2]));
// PE pe3( .in_a(pe_in_a[3]), .in_b(pe_in_b[3]), .out_c(pe_out_c[3]));

// assign out_c = (pe_out_c[0] << 8) + (pe_out_c[1] << 4) + (pe_out_c[2] << 4) + (pe_out_c[3] << 0);

wire    [15:0] pe_in_a[3:0];
wire    [15:0] pe_in_b[3:0];
wire    [ 9:0] pe_out_c[3:0];

assign pe_in_a[0] = {in_a[60+4-1:60], in_a[52+4-1:52], in_a[44+4-1:44], in_a[36+4-1:36]}; // left  top a
assign pe_in_a[1] = {in_a[56+4-1:56], in_a[48+4-1:48], in_a[40+4-1:40], in_a[32+4-1:32]}; // left  bot a
assign pe_in_a[2] = {in_a[28+4-1:28], in_a[20+4-1:20], in_a[12+4-1:12], in_a[ 4+4-1: 4]}; // right top a
assign pe_in_a[3] = {in_a[24+4-1:24], in_a[16+4-1:16], in_a[ 8+4-1: 8], in_a[ 0+4-1: 0]}; // right bot a

assign pe_in_b[0] = {in_b[60+4-1:60], in_b[52+4-1:52], in_b[44+4-1:44], in_b[36+4-1:36]}; // left  top b
assign pe_in_b[1] = {in_b[56+4-1:56], in_b[48+4-1:48], in_b[40+4-1:40], in_b[32+4-1:32]}; // left  bot b
assign pe_in_b[2] = {in_b[28+4-1:28], in_b[20+4-1:20], in_b[12+4-1:12], in_b[ 4+4-1: 4]}; // right top b
assign pe_in_b[3] = {in_b[24+4-1:24], in_b[16+4-1:16], in_b[ 8+4-1: 8], in_b[ 0+4-1: 0]}; // right bot b

PE pe0( .in_a(pe_in_a[0]), .in_b(pe_in_b[0]), .out_c(pe_out_c[0]));
PE pe1( .in_a(pe_in_a[1]), .in_b(pe_in_b[1]), .out_c(pe_out_c[1]));
PE pe2( .in_a(pe_in_a[2]), .in_b(pe_in_b[2]), .out_c(pe_out_c[2]));
PE pe3( .in_a(pe_in_a[3]), .in_b(pe_in_b[3]), .out_c(pe_out_c[3]));

assign out_c = pe_out_c[0] + pe_out_c[1] + pe_out_c[2] + pe_out_c[3];

endmodule