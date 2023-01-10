module PE (
	in_a,
	in_b,
	out_c
);

input	[15:0] in_a; // {a4, a3, a2, a1}
input	[15:0] in_b; // {b4, b3, b2, b1}
output	[9:0] out_c;


wire    [7:0] psum_l0[3:0]; // intermediate value
wire    [8:0] psum_l1[1:0];

// out_c = a_1 * b_1 + a_2 * b_2 + a_3 * b_3 + a_4 * b_4
assign psum_l0[0] = in_a[ 3: 0] * in_b[ 3: 0];  // 11100001 ~ 00000000
assign psum_l0[1] = in_a[ 7: 4] * in_b[ 7: 4];
assign psum_l0[2] = in_a[11: 8] * in_b[11: 8];
assign psum_l0[3] = in_a[15:12] * in_b[15:12];

assign psum_l1[0] = psum_l0[0] + psum_l0[1];    // 111000010 ~ 000000000
assign psum_l1[1] = psum_l0[2] + psum_l0[3];

assign out_c = psum_l1[0] + psum_l1[1];         // 1110000100 ~ 0000000000

endmodule