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

`include "TPU.v"
`include "global_buffer.v"

module Cfu (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output              rsp_valid,
  input               rsp_ready,
  output     [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);

// op0 --> reset matrix index
// op1 --> store 2 32bits to global buffer A & B
// op2 --> load 32bits from global buffer C
// op3 --> perform matrix multiplication (K, {M,N})

// ===============================================================
//                      Parameter Declaration 
// ===============================================================
// FSM
parameter STATE_IDLE =      'd0;
parameter STATE_WAIT =      'd1;
parameter STATE_CALC =      'd2;
parameter STATE_OUTPUT =    'd3;

// Global buffer
parameter GBUFF_ADDR_BITS =      14;
parameter I_GBUFF_DATA_BITS =    32;
parameter O_GBUFF_DATA_BITS =   128;

// ===============================================================
//                      Wire & Register
// ===============================================================
// FSM
reg     [1:0] current_state, next_state;
wire    is_op0, is_op1, is_op2, is_op3;
wire    finish_calc;

// Metadata Information
// Matrix A[M,K] @ B[K,N]
reg     [11:0] M;
reg     [7:0]  K, N;
reg     [31:0] cmd_payload_inputs_0_buf;

// output
reg     [31:0] single_acc_result;

// Global Buffer Signal
wire    A_wr_en, B_wr_en, C_wr_en;
wire    [GBUFF_ADDR_BITS-1:0] A_index, B_index, C_index;
wire    [I_GBUFF_DATA_BITS:0] A_data_in, B_data_in;
wire    [O_GBUFF_DATA_BITS:0] C_data_in;
wire    [I_GBUFF_DATA_BITS-1] A_data_out, B_data_out;
wire    [O_GBUFF_DATA_BITS:0] C_data_out;

wire    is_store_A, is_store_B;

// CPU
reg     A_wr_en_CPU, B_wr_en_CPU;
reg     [GBUFF_ADDR_BITS-1:0] A_index_CPU, B_index_CPU, C_index_CPU;

// TPU
wire    busy_TPU;
wire    A_wr_en_TPU, B_wr_en_TPU, C_wr_en_TPU;
wire    [GBUFF_ADDR_BITS-1:0] A_index_TPU, B_index_TPU, C_index_TPU;

// ===============================================================
//                          Design
// ===============================================================
// FSM
// current state
// TBD check all posedge and try to remove posedge reset
always @(posedge clk or posedge reset) begin
    if (reset)  current_state <= STATE_IDLE;
    else        current_state <= next_state;
end

// next state
always @(*) begin
    next_state = current_state;
    case (current_state)
        STATE_IDLE: if (cmd_valid) begin
            if (is_op2)         next_state = STATE_WAIT;
            else if (is_op3)    next_state = STATE_CALC;
            else                next_state = STATE_OUTPUT;
        end
        STATE_WAIT:             next_state = STATE_OUTPUT;
        STATE_CALC: if (finish_calc) begin
                                next_state = STATE_OUTPUT;
        end
        default:                next_state = current_state;
    endcase
end
assign is_op0 = (cmd_valid) && (cmd_payload_function_id[2:0] == 0);
assign is_op1 = (cmd_valid) && (cmd_payload_function_id[2:0] == 1);
assign is_op2 = (cmd_valid) && (cmd_payload_function_id[2:0] == 2);
assign is_op3 = (cmd_valid) && (cmd_payload_function_id[2:0] == 3);
assign finish_calc = !busy_TPU;

// output logic
assign rsp_valid = (current_state == STATE_OUTPUT);
assign cmd_ready = ~rsp_valid;

// select output -- note that we're not fully decoding the 3 function_id bits
assign rsp_payload_outputs_0 = single_acc_result;

always @(posedge clk or posedge reset) begin
    if (reset)          single_acc_result <= 0;
    else if (curr_state == STATE_WAIT) begin
        case (cmd_payload_inputs_0_buf[1:0])
            0:          single_acc_result <= C_data_out[ 31: 0];
            1:          single_acc_result <= C_data_out[ 63:32];
            2:          single_acc_result <= C_data_out[ 95:64];
            3:          single_acc_result <= C_data_out[127:96];
            default:    single_acc_result <= 0;
        endcase
    end
end

// metadata signal
always @(posedge clk or posedge reset) begin
    if (reset) begin
        M <= 0;
        K <= 0;
        N <= 0;
    end
    else if (in_valid) begin
        // cfu_op3(/* funct7= */ 0, output_height * output_width, input_depth << 16 + output_depth);
        M <= cmd_payload_inputs_0;
        K <= cmd_payload_inputs_1[31:16];
        N <= cmd_payload_inputs_0[15: 0];
    end
end

always @(posedge clk or posedge reset) begin
    if (reset)  cmd_payload_inputs_0_buf <= 0;
    else        cmd_payload_inputs_0_buf <= cmd_payload_inputs_0;
end

// global buffer
// TBD try remove reset
global_buffer #( .ADDR_BITS(GBUFF_ADDR_BITS), .DATA_BITS(I_GBUFF_DATA_BITS)) gbuff_A(
    .clk(clk),
    // .rst_n(!reset),
    .wr_en(A_wr_en),
    .index(A_index),
    .data_in(A_data_in),
    .data_out(A_data_out)
);

global_buffer #( .ADDR_BITS(GBUFF_ADDR_BITS), .DATA_BITS(I_GBUFF_DATA_BITS)) gbuff_B(
    .clk(clk),
    // .rst_n(!reset),
    .wr_en(B_wr_en),
    .index(B_index),
    .data_in(B_data_in),
    .data_out(B_data_out)
);

global_buffer #( .ADDR_BITS(GBUFF_ADDR_BITS), .DATA_BITS(O_GBUFF_DATA_BITS)) gbuff_C(
    .clk(clk),
    // .rst_n(!reset),
    .wr_en(C_wr_en),
    .index(C_index),
    .data_in(C_data_in),
    .data_out(C_data_out)
);

assign A_wr_en = (curr_state == STATE_CALC) ? A_wr_en_TPU : A_wr_en_CPU;
assign B_wr_en = (curr_state == STATE_CALC) ? B_wr_en_TPU : B_wr_en_CPU;
assign C_wr_en = (curr_state == STATE_CALC) ? C_wr_en_TPU : 0;

assign A_index = (curr_state == STATE_CALC) ? A_index_TPU : A_index_CPU;
assign B_index = (curr_state == STATE_CALC) ? B_index_TPU : B_index_CPU;
assign C_index = (curr_state == STATE_CALC) ? C_index_TPU : C_index_CPU;

assign A_data_in = cmd_payload_inputs_0_buf;
assign B_data_in = cmd_payload_inputs_0_buf;

assign is_store_A = is_op1 &&  cmd_payload_inputs_1[3];
assign is_store_B = is_op1 && !cmd_payload_inputs_1[3];

// CPU signal
always @(posedge clk or posedge reset) begin
    if (reset)              A_wr_en_CPU <= 0;
    else if (is_store_A)    A_wr_en_CPU <= 1;
    else                    A_wr_en_CPU <= 0;
end

always @(posedge clk or posedge reset) begin
    if (reset)              B_wr_en_CPU <= 0;
    else if (is_store_B)    B_wr_en_CPU <= 1;
    else                    B_wr_en_CPU <= 0;
end

always @(posedge clk or posedge reset) begin
    if (reset)                              A_index_CPU <= 0 - 1;
    else if (is_op0)                        A_index_CPU <= 0 - 1;
    else if (is_store_A)                    A_index_CPU <= A_index_CPU + 1;
    else                                    A_index_CPU <= A_index_CPU;
end

always @(posedge clk or posedge reset) begin
    if (reset)                              B_index_CPU <= 0 - 1;
    else if (is_op0)                        B_index_CPU <= 0 - 1;
    else if (is_store_B)                    B_index_CPU <= B_index_CPU + 1;
    else                                    B_index_CPU <= B_index_CPU;
end

always @(posedge clk or posedge reset) begin
    if (reset)                              C_index_CPU <= 0;
    else if (is_op2)                        C_index_CPU <= cmd_payload_inputs_0[GBUFF_ADDR_BITS+1:2];
    else                                    C_index_CPU <= C_index_CPU;
end

// TPU

TPU tpu(
  .clk(clk);
  .rst_n(!reset);
  .in_valid(is_op3);

  .K(K);
  .M(M);
  .N(N);
  .busy(busy_TPU);

  .A_wr_en(A_wr_en_TPU);
  .A_index(A_index_TPU);
  .A_data_in();
  .A_data_out(A_data_out);

  .B_wr_en(B_wr_en_TPU);
  .B_index(B_index_TPU);
  .B_data_in();
  .B_data_out(B_data_out);

  .C_wr_en(C_wr_en_TPU);
  .C_index(C_index_TPU);
  .C_data_in(C_data_in);
  .C_data_out();
);
  
endmodule
