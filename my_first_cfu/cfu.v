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

  wire [15:0] prod_0, prod_1, prod_2, prod_3;
  wire [31:0] sum_prods;

  // SIMD multiply step:
  // assign prod_0 =cmd_payload_inputs_0[7 : 0] * cmd_payload_inputs_1[7 : 0];
  // assign prod_1 =cmd_payload_inputs_0[15: 8] * cmd_payload_inputs_1[15: 8];
  // assign prod_2 =cmd_payload_inputs_0[23:16] * cmd_payload_inputs_1[23:16];
  // assign prod_3 =cmd_payload_inputs_0[31:24] * cmd_payload_inputs_1[31:24];
  // assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3;
  Bitblade bitblade( .in_a(cmd_payload_inputs_0), .in_b(cmd_payload_inputs_1), .out_c(sum_prods));

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
    end else if (rsp_valid) begin // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin // Accumulate step:
      rsp_valid <= 1'b1;
      rsp_payload_outputs_0 <= |cmd_payload_function_id[9:3] ? 32'b0 : rsp_payload_outputs_0 + sum_prods;
    end
  end
endmodule
