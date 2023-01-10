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

// ===============================================================
//                      Wire & Register
// ===============================================================
// FSM
// since all instruction could be done within 1 cycle, FSM is not required
wire  [2:0] opcode;
wire  is_setting_mode, is_resetting_acc, is_accumlating, is_loading_upper;

// Metadata
reg         mode; // 0/1: 8/4-bit data foramt

// Bitblade Signal
reg   [31:0] upper_bitblade_in_a;
reg   [31:0] upper_bitblade_in_b;
wire  [63:0] bitblade_in_a;
wire  [63:0] bitblade_in_b;
wire  [31:0] bitblade_out_c;

// ===============================================================
//                          Design
// ===============================================================
// FSM
assign opcode = cmd_payload_function_id[2:0];
assign is_setting_mode =  (cmd_valid) && (opcode == 0);
assign is_resetting_acc = (cmd_valid) && (opcode == 1);
assign is_loading_upper = (cmd_valid) && (opcode == 2);
assign is_accumlating =   (cmd_valid) && (opcode == 3);

// Metadata
always @(posedge clk) begin
  if (reset)
    mode <= 0; // default is set to mode 0
  else if (is_setting_mode)
    mode <= cmd_payload_function_id[3];
end

// Output Logic
// only not ready for a command when we have a response.
assign cmd_ready = ~rsp_valid;

always @(posedge clk) begin
  if (reset)          rsp_valid <= 1'b0;
  else if (rsp_valid) rsp_valid <= ~rsp_ready;  // waiting for hand off response to CPU. 
  else if (cmd_valid) rsp_valid <= 1'b1;        // accumulation step
end

always @(posedge clk) begin
  if (reset)
    rsp_payload_outputs_0 <= 32'b0;
  else if (is_resetting_acc)
    rsp_payload_outputs_0 <= 32'b0;
  else if (is_accumlating)
    rsp_payload_outputs_0 <= rsp_payload_outputs_0 + bitblade_out_c;
end

// SIMD modules
always @(posedge clk) begin
  if (reset)                  upper_bitblade_in_a <= 0;
  else if (is_loading_upper)  upper_bitblade_in_a <= cmd_payload_inputs_0;
end

always @(posedge clk) begin
  if (reset)                  upper_bitblade_in_b <= 0;
  else if (is_loading_upper)  upper_bitblade_in_b <= cmd_payload_inputs_1;
end

assign bitblade_in_a = {upper_bitblade_in_a, cmd_payload_inputs_0};
assign bitblade_in_b = {upper_bitblade_in_b, cmd_payload_inputs_1};
Bitblade bitblade(
  .mode(mode),
  .in_a(bitblade_in_a),
  .in_b(bitblade_in_b),
  .out_c(bitblade_out_c)
);
endmodule
