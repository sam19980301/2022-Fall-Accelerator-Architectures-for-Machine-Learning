// Copyright 2021 The CFU-Playground Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "bitblade.v"

module Cfu (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid,
  input               rsp_ready,
  output reg [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);

// wire [15:0] prod_0, prod_1, prod_2, prod_3;
// wire signed [31:0] sum_prods;
// // SIMD multiply step
// assign prod_0 = inputs[0] * filters[0];
// assign prod_1 = inputs[1] * filters[1];
// assign prod_2 = inputs[2] * filters[2];
// assign prod_3 = inputs[3] * filters[3];
// assign sum_prods = $signed(prod_0) + $signed(prod_1) + $signed(prod_2) + $signed(prod_3);

// wire [15:0] inputs[3:0];
// wire [15:0] filters[3:0];
// // input & filter slice
// // input[0,1,2,3] =   16'b 0000 0000 ABCD EFGH
// // filter[0,1,2,3] =  16'b AAAA AAAA ABCD EFGH
// assign inputs[0] = {8'b0, ~cmd_payload_inputs_0[ 8-1], cmd_payload_inputs_0[ 8-2: 0]};
// assign inputs[1] = {8'b0, ~cmd_payload_inputs_0[16-1], cmd_payload_inputs_0[16-2: 8]};
// assign inputs[2] = {8'b0, ~cmd_payload_inputs_0[24-1], cmd_payload_inputs_0[24-2:16]};
// assign inputs[3] = {8'b0, ~cmd_payload_inputs_0[32-1], cmd_payload_inputs_0[32-2:24]};

// assign filters[0] = {{8{cmd_payload_inputs_1[ 8-1]}}, cmd_payload_inputs_1[ 8-1: 0]}; // signed-extension
// assign filters[1] = {{8{cmd_payload_inputs_1[16-1]}}, cmd_payload_inputs_1[16-1: 8]}; // signed-extension
// assign filters[2] = {{8{cmd_payload_inputs_1[24-1]}}, cmd_payload_inputs_1[24-1:16]}; // signed-extension
// assign filters[3] = {{8{cmd_payload_inputs_1[32-1]}}, cmd_payload_inputs_1[32-1:24]}; // signed-extension

wire [31:0] sum_prods;

wire [31:0] bitblade_in_a;
wire [31:0] bitblade_in_b[1:0];
wire [17:0] bitblade_out_c[1:0];

// input[15:0] * filter[15:0] = 
//   input[15:8] * filter[15:8] + --> 0
//   input[15:8] * filter[ 7:0] + --> 0
//   input[ 7:0] * filter[15:8] + --> 8b * 8b Bitblade0
//   input[ 7:0] * filter[ 7:0]   --> 8b * 8b Bitblade1

assign bitblade_in_a = {
  ~cmd_payload_inputs_0[32-1], cmd_payload_inputs_0[32-2:24],
  ~cmd_payload_inputs_0[24-1], cmd_payload_inputs_0[24-2:16],
  ~cmd_payload_inputs_0[16-1], cmd_payload_inputs_0[16-2: 8],
  ~cmd_payload_inputs_0[ 8-1], cmd_payload_inputs_0[ 8-2: 0]
};

assign bitblade_in_b[0] = {
  {8{cmd_payload_inputs_1[32-1]}},
  {8{cmd_payload_inputs_1[24-1]}},
  {8{cmd_payload_inputs_1[16-1]}},
  {8{cmd_payload_inputs_1[ 8-1]}}
};

// assign bitblade_in_b[1] = {
//   cmd_payload_inputs_1[ 8-1: 0],
//   cmd_payload_inputs_1[16-1: 8],
//   cmd_payload_inputs_1[24-1:16],
//   cmd_payload_inputs_1[32-1:24]
// };

assign bitblade_in_b[1] = cmd_payload_inputs_1;

Bitblade bitblade0(
  .in_a(  bitblade_in_a     ),
  .in_b(  bitblade_in_b[0]  ),
  .out_c( bitblade_out_c[0] )
);

Bitblade bitblade1(
  .in_a(  bitblade_in_a     ),
  .in_b(  bitblade_in_b[1]  ),
  .out_c( bitblade_out_c[1] )
);

assign sum_prods = $signed(bitblade_out_c[0] << 8) + $signed(bitblade_out_c[1]);

// Only not ready for a command when we have a response.
assign cmd_ready = ~rsp_valid;

always @(posedge clk) begin
  if (reset) begin
    rsp_payload_outputs_0 <= 32'b0;
    rsp_valid <= 1'b0;
  end else if (rsp_valid) begin
    // Waiting to hand off response to CPU.
    rsp_valid <= ~rsp_ready;
  end else if (cmd_valid) begin
    rsp_valid <= 1'b1;
    // Accumulate step:
    rsp_payload_outputs_0 <= |cmd_payload_function_id[9:3] ? 32'b0 : rsp_payload_outputs_0 + {{16{sum_prods[15]}}, sum_prods[15:0]}; // sum_prods    
  end
end
endmodule