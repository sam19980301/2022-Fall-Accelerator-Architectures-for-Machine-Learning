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

`include "global_buffer.v"
`include "TPU.v"

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

// ===============================================================
//                      Parameter Declaration 
// ===============================================================
// FSM
parameter STATE_IDLE =      'd0;
parameter STATE_LOAD =      'd1;
parameter STATE_STORE =     'd2;
parameter STATE_CALC =      'd3;
parameter STATE_OUTPUT =    'd4;

// Global buffer
// Ideally the ADDR_BITS would be 13 / 14 / 14 for fitting
// Smaller ADDR_BITS to fit into FPGA board
parameter A_GBUFF_ADDR_BITS =     8;
parameter B_GBUFF_ADDR_BITS =    14;
parameter C_GBUFF_ADDR_BITS =     8;
// parameter A_GBUFF_ADDR_BITS =    13;
// parameter B_GBUFF_ADDR_BITS =    14;
// parameter C_GBUFF_ADDR_BITS =    14;
parameter A_GBUFF_DATA_BITS =    32;
parameter B_GBUFF_DATA_BITS =    32;
parameter C_GBUFF_DATA_BITS =   128;

// TPU
parameter TPU_ADDR_BITS = 9; // MAX_SHAPE: 256(511)
// parameter TPU_ADDR_BITS = 12; // MAX_SHAPE: 2304(4095)

// Spec
// op0: Load Store 
//      funct7 = 0: Load  A output = A[input_0]
//      funct7 = 1: Load  B output = B[input_0]
//      funct7 = 2: Load  C output = C[input_0]     (redundent)
//      funct7 = 3: Store A A[input_0] = input_1    (redundent)
//      funct7 = 4: Store B B[input_0] = input_1    (redundent)
//      funct7 = 5: Store C C[input_0] = input_1
// op1: Matrix Multiplication


// ===============================================================
//                      Wire & Register
// ===============================================================
// FSM
reg     [2:0] current_state, next_state;
wire    [2:0] opcode;
wire    [6:0] funct7;
reg     [6:0] funct7_last_cycle;
wire    is_load,  is_load_A,  is_load_B,  is_load_C;
wire    is_store, is_store_A, is_store_B, is_store_C;
wire    is_calc;
wire    finish_calc;

// Metadata Information
// Matrix A[M,K] @ B[K,N]
reg     [TPU_ADDR_BITS-1:0] M;
reg     [TPU_ADDR_BITS-1:0] K, N;

// output
reg     [31:0] outputs_reg;
reg     [31:0] sub_C_data_out;
reg     [31:0] cmd_payload_inputs_0_last_cycle;

// Global Buffer Signal
wire    A_wr_en;
wire    [A_GBUFF_ADDR_BITS-1:0] A_index;
reg     [A_GBUFF_DATA_BITS-1:0] A_data_in;
wire    [A_GBUFF_DATA_BITS-1:0] A_data_out;

wire    B_wr_en;
wire    [B_GBUFF_ADDR_BITS-1:0] B_index;
reg     [B_GBUFF_DATA_BITS-1:0] B_data_in;
wire    [B_GBUFF_DATA_BITS-1:0] B_data_out;

wire    C_wr_en;
wire    [C_GBUFF_ADDR_BITS-1:0] C_index;
wire    [C_GBUFF_DATA_BITS-1:0] C_data_in;
wire    [C_GBUFF_DATA_BITS-1:0] C_data_out;

// CPU
reg     A_wr_en_CPU, B_wr_en_CPU, C_wr_en_CPU;
reg     [A_GBUFF_ADDR_BITS-1:0] A_index_CPU;
reg     [B_GBUFF_ADDR_BITS-1:0] B_index_CPU;
reg     [C_GBUFF_ADDR_BITS-1:0] C_index_CPU;

// TPU
wire    busy_TPU;
wire    C_wr_en_TPU;
wire    [16-1:0] A_index_TPU;
wire    [16-1:0] B_index_TPU;
wire    [16-1:0] C_index_TPU;

// ===============================================================
//                          Design
// ===============================================================
// FSM
// current state
always @(posedge clk or posedge reset) begin
    if (reset)  current_state <= STATE_IDLE;
    else        current_state <= next_state;
end

// next state
always @(*) begin
    next_state = current_state;
    case (current_state)
        STATE_IDLE: if (cmd_valid) begin
            if (is_load)                next_state = STATE_LOAD;
            else if (is_store)          next_state = STATE_STORE;
            else if (is_calc)           next_state = STATE_CALC;
        end
        STATE_LOAD:                     next_state = STATE_OUTPUT;
        STATE_STORE:                    next_state = STATE_OUTPUT;
        STATE_CALC: if (finish_calc)    next_state = STATE_OUTPUT;
        STATE_OUTPUT: if (rsp_ready)    next_state = STATE_IDLE;
        default:                        next_state = current_state;
    endcase
end
assign opcode = cmd_payload_function_id[2:0];
assign funct7 = cmd_payload_function_id[9:3];
always @(posedge clk) begin
    funct7_last_cycle <= funct7;
end

assign is_load =    is_load_A | is_load_B | is_load_C;
assign is_store =   is_store_A | is_store_B | is_store_C;
assign is_calc =    (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 1);

assign is_load_A =  (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 0) && (funct7 == 0);
assign is_load_B =  (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 0) && (funct7 == 1);
assign is_load_C =  (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 0) && (funct7 == 2);
assign is_store_A = (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 0) && (funct7 == 3);
assign is_store_B = (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 0) && (funct7 == 4);
assign is_store_C = (current_state == STATE_IDLE) && (cmd_valid) && (opcode == 0) && (funct7 == 5);

assign finish_calc = !busy_TPU;

// output logic
assign rsp_valid = (current_state == STATE_OUTPUT);
assign cmd_ready = ~rsp_valid;
assign rsp_payload_outputs_0 = outputs_reg;
always @(posedge clk or posedge reset) begin
    if (reset)          outputs_reg <= 0;
    else if (current_state == STATE_LOAD) begin
        case (funct7_last_cycle)
            0:          outputs_reg <= A_data_out;
            1:          outputs_reg <= B_data_out;
            2:          outputs_reg <= sub_C_data_out;
            default:    outputs_reg <= 0;
        endcase
    end
    else                outputs_reg <= outputs_reg;
end

// TBD cmd_payload_inputs_0_last_cycle could be truncated, and the index decoding could be implented in hardware
always @(*) begin
    case (cmd_payload_inputs_0_last_cycle[1:0])
        0: sub_C_data_out =         C_data_out[127:96];
        1: sub_C_data_out =         C_data_out[ 95:64];
        2: sub_C_data_out =         C_data_out[ 63:32];
        3: sub_C_data_out =         C_data_out[ 31: 0];
        default: sub_C_data_out =   0;
    endcase
end
always @(posedge clk or posedge reset) begin
    if (reset)  cmd_payload_inputs_0_last_cycle <= 0;
    else        cmd_payload_inputs_0_last_cycle <= cmd_payload_inputs_0;
end

// global buffer A
global_buffer #( .ADDR_BITS(A_GBUFF_ADDR_BITS), .DATA_BITS(A_GBUFF_DATA_BITS)) gbuff_A(
    .clk(clk), .wr_en(A_wr_en), .index(A_index), .data_in(A_data_in), .data_out(A_data_out)
);

global_buffer #( .ADDR_BITS(B_GBUFF_ADDR_BITS), .DATA_BITS(B_GBUFF_DATA_BITS)) gbuff_B(
    .clk(clk), .wr_en(B_wr_en), .index(B_index), .data_in(B_data_in), .data_out(B_data_out)
);

global_buffer #( .ADDR_BITS(C_GBUFF_ADDR_BITS), .DATA_BITS(C_GBUFF_DATA_BITS)) gbuff_C(
    .clk(clk), .wr_en(C_wr_en), .index(C_index), .data_in(C_data_in), .data_out(C_data_out)
);

assign A_wr_en = (current_state == STATE_CALC) ? 0 :           A_wr_en_CPU;
assign B_wr_en = (current_state == STATE_CALC) ? 0 :           B_wr_en_CPU;
assign C_wr_en = (current_state == STATE_CALC) ? C_wr_en_TPU : C_wr_en_CPU;

assign A_index = (current_state == STATE_CALC) ? A_index_TPU : A_index_CPU;
assign B_index = (current_state == STATE_CALC) ? B_index_TPU : B_index_CPU;
assign C_index = (current_state == STATE_CALC) ? C_index_TPU : C_index_CPU;

always @(posedge clk or posedge reset) begin
    if (reset)  A_data_in <= 0;
    else        A_data_in <= cmd_payload_inputs_1;
end
always @(posedge clk or posedge reset) begin
    if (reset)  B_data_in <= 0;
    else        B_data_in <= cmd_payload_inputs_1;
end

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
    if (reset)              C_wr_en_CPU <= 0;
    else if (is_store_C)    C_wr_en_CPU <= 1;
    else                    C_wr_en_CPU <= 0;
end

always @(posedge clk or posedge reset) begin
    if (reset)              A_index_CPU <= 0;
    else if (is_store_A)    A_index_CPU <= cmd_payload_inputs_0;
    else if (is_load_A)     A_index_CPU <= cmd_payload_inputs_0;
    else                    A_index_CPU <= A_index_CPU;
end
always @(posedge clk or posedge reset) begin
    if (reset)              B_index_CPU <= 0;
    else if (is_store_B)    B_index_CPU <= cmd_payload_inputs_0;
    else if (is_load_B)     B_index_CPU <= cmd_payload_inputs_0;
    else                    B_index_CPU <= B_index_CPU;
end
always @(posedge clk or posedge reset) begin
    if (reset)              C_index_CPU <= 0;
    else if (is_store_C)    C_index_CPU <= cmd_payload_inputs_0;
    else if (is_load_C)     C_index_CPU <= cmd_payload_inputs_0 / 4;
    else                    C_index_CPU <= C_index_CPU;
end

// TPU
TPU #(.ADDR_BITS(TPU_ADDR_BITS)) tpu(
  .clk(clk),
  .rst_n(!reset),
  .in_valid(is_calc),

  .K(K),
  .M(M),
  .N(N),
  .busy(busy_TPU),

  .A_wr_en(),
  .A_index(A_index_TPU),
  .A_data_in(),
  .A_data_out(A_data_out),

  .B_wr_en(),
  .B_index(B_index_TPU),
  .B_data_in(),
  .B_data_out(B_data_out),

  .C_wr_en(C_wr_en_TPU),
  .C_index(C_index_TPU),
  .C_data_in(C_data_in),
  .C_data_out()
);

always @(*) begin
    // A[M,K] @ B[K,N]
    M = cmd_payload_inputs_0;
    K = cmd_payload_inputs_1[31:16];
    N = cmd_payload_inputs_1[15: 0];
end
endmodule