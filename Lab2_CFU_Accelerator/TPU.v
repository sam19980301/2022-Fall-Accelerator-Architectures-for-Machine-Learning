module TPU(
    clk,
    rst_n,

    in_valid,
    K,
    M,
    N,
    busy,

    A_wr_en,
    A_index,
    A_data_in,
    A_data_out,

    B_wr_en,
    B_index,
    B_data_in,
    B_data_out,

    C_wr_en,
    C_index,
    C_data_in,
    C_data_out
);


input clk;
input rst_n;
input            in_valid;
// input [7:0]      K;
input [7:0]     K;
input [11:0]      M;
input [7:0]      N;
output  reg      busy;

output           A_wr_en;
// output [15:0]    A_index;
output [13:0]    A_index;
output [31:0]    A_data_in;
input  [31:0]    A_data_out;

output           B_wr_en;
// output [15:0]    B_index;
output [13:0]    B_index;
output [31:0]    B_data_in;
input  [31:0]    B_data_out;

output           C_wr_en;
// output [15:0]    C_index;
output [13:0]    C_index;
output [127:0]   C_data_in;
input  [127:0]   C_data_out;

// ===============================================================
//                      Parameter Declaration 
// ===============================================================
// SRAM

// FSM
parameter STATE_IDLE =      'd0;
parameter STATE_CALC =      'd1;
parameter STATE_WRITE =     'd2;
parameter STATE_OUTPUT =    'd3;

genvar idx, idy;

// ===============================================================
//                      Wire & Register
// ===============================================================
// FSM
reg     [1:0] current_state, next_state;
// reg     [5:0] cnt;          // A_row_tile counting
reg     [9:0] cnt;          // A_row_tile counting
reg     [5:0] subcnt;       // B_col_tile counting
reg     [8:0] tile_cycle;   // within_tile cycle counting
reg     [1:0] write_cycle;  // writing cycle counting
wire    last_tile, last_tiles;
wire    not_finish_feedsig, finish_tile, finish_tiles, finish_calc, finish_write;
reg     [1:0] last_write_cycle;

// metadata information
// reg     [7:0] A_row, A_col, B_row, B_col;
reg     [11:0] A_row;
reg     [7:0]  A_col, B_row, B_col;
// wire    [5:0]  A_row_tile, B_col_tile;
wire    [7:0]  A_row_tile;
wire    [5:0]  B_col_tile;

// SRAM signals
reg     [127:0] C_data_in_reg;

// PE port
reg     [7:0] in_left_buf_arr[3:0][3:0], in_top_buf_arr[3:0][3:0];
reg     pe_reset;
wire    [7:0] in_left_arr[3:0][3:0], in_top_arr[3:0][3:0];
wire    [7:0] out_bot_arr[3:0][3:0], out_right_arr[3:0][3:0];
wire    [31:0] out_sum_arr[3:0][3:0];

// ===============================================================
//                          Design
// ===============================================================
// FSM
// current state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= STATE_IDLE;
    else        current_state <= next_state;
end

// next state
always @(*) begin
    next_state = current_state;
    case (current_state)
        STATE_IDLE: if (in_valid)       next_state = STATE_CALC;
        STATE_CALC:                     next_state = STATE_OUTPUT;
        STATE_OUTPUT:                   next_state = STATE_IDLE;
        default:                        next_state = current_state;
    endcase
end
assign last_tile =          (B_col_tile == subcnt);
assign last_tiles =         (A_row_tile == cnt);
assign not_finish_feedsig = (current_state == STATE_CALC) && (tile_cycle <= A_col - 1);
assign finish_tile =        (tile_cycle == A_col + 7);
assign finish_tiles =       (last_tile) && (finish_tile);
assign finish_calc =        (last_tiles) && (finish_tiles);
assign finish_write =       (current_state == STATE_WRITE) && (write_cycle == last_write_cycle);
always @(*) begin
    if (last_tiles) begin // consider the last tile for each row of output matrix
        case (B_col[1:0])
            'd0:        last_write_cycle = 3;
            'd1:        last_write_cycle = 0;
            'd2:        last_write_cycle = 1;
            'd3:        last_write_cycle = 2;
            default:    last_write_cycle = 0;
        endcase
    end
    else                last_write_cycle = 3;
end

// counter information
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                 cnt <= 0;
    else if (finish_write) begin
        if (finish_calc)        cnt <= 0;
        else if (finish_tiles)  cnt <= cnt + 1; // A-row tile counting
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)             subcnt <= 0;
    else if (finish_write) begin
        if (finish_tiles)   subcnt <= 0;
        else                subcnt <= subcnt + 1; // B-col tile counting
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                                 tile_cycle <= 0;
    else if ((current_state == STATE_CALC) && (!finish_tile))   tile_cycle <= tile_cycle + 1; // cycle within tile
    else if (finish_write)                                      tile_cycle <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                             write_cycle <= 0;
    else if (current_state == STATE_WRITE)  write_cycle <= write_cycle + 1; // writing cycle counting
end

// output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                             busy <= 0;
    else if (in_valid)                      busy <= 1;
    else if (current_state == STATE_OUTPUT) busy <= 0;
end

assign A_wr_en =    0;
assign A_index =    cnt * A_col + tile_cycle;
assign A_data_in =  0;
assign B_wr_en =    0;
assign B_index =    subcnt * B_row + tile_cycle;
assign B_data_in =  0;
assign C_wr_en =    (current_state == STATE_WRITE);
assign C_index =    (subcnt * A_row + cnt * 4) + write_cycle; // memory format of SRAM C: tile-based w/o transpose
assign C_data_in =  C_data_in_reg;
always @(*) begin
    case (write_cycle)
        // memory format
        'd0:        C_data_in_reg = {out_sum_arr[0][0], out_sum_arr[0][1], out_sum_arr[0][2], out_sum_arr[0][3]};
        'd1:        C_data_in_reg = {out_sum_arr[1][0], out_sum_arr[1][1], out_sum_arr[1][2], out_sum_arr[1][3]};
        'd2:        C_data_in_reg = {out_sum_arr[2][0], out_sum_arr[2][1], out_sum_arr[2][2], out_sum_arr[2][3]};
        'd3:        C_data_in_reg = {out_sum_arr[3][0], out_sum_arr[3][1], out_sum_arr[3][2], out_sum_arr[3][3]};
        default:    C_data_in_reg = 0;
    endcase
end

// metadata signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        A_row <= 0;
        A_col <= 0;
        B_col <= 0;
    end
    else if (in_valid) begin
        A_row <= M;
        A_col <= K;
        B_col <= N;
    end
end
always @(*) begin
    B_row = A_col;
end
assign A_row_tile = A_row[7:2] + |A_row[1:0] - 1; // zero-indexed
assign B_col_tile = B_col[7:2] + |B_col[1:0] - 1; // zero-indexed

// Cycle    PE[0][0]                                    PE[0][1]        PE[0][2]        PE[0][3]        PE[1][3]        PE[2][3]        PE[3][3]
// -1       Set SRAM signal A[0,0],B[0,0]
//  0       Receive SRAM / Set PE signal A[0,0],B[0,0]
//  1       Cal A[0,0]*B[0,0]
//  2       Cal A[0,1]*B[1,0]                           A[0,0]*B[0,1]
//  3       Cal A[0,2]*B[2,0]                           A[0,1]*B[1,1]   A[0,0]*B[0,2]
//  4       Cal A[0,3]*B[3,0]                           A[0,2]*B[2,1]   A[0,1]*B[1,2]   A[0,0]*B[0,3]
//  5       Cal A[0,4]*B[4,0]                           A[0,3]*B[3,1]   A[0,2]*B[2,2]   A[0,1]*B[1,3]   A[1,0]*B[0,3]
//  6       Cal A[0,5]*B[5,0]                           A[0,4]*B[4,1]   A[0,3]*B[3,2]   A[0,2]*B[2,3]   A[1,1]*B[1,3]   A[2,0]*B[0,3]
//  7       Cal A[0,6]*B[6,0]                           A[0,5]*B[5,1]   A[0,4]*B[4,2]   A[0,3]*B[3,3]   A[1,2]*B[2,3]   A[2,1]*B[1,3]   A[3,0]*B[0,3]
//  8       Cal A[0,7]*B[7,0]                           A[0,6]*B[6,1]   A[0,5]*B[5,2]   A[0,4]*B[4,3]   A[1,3]*B[3,3]   A[2,2]*B[2,3]   A[3,1]*B[1,3]
// ...
// K+1      Cal A[0,K]*B[K,0]
// K+2                                                  A[0,K]*B[K,1]
// K+3                                                                  A[0,K]*B[K,2]
// K+4                                                                                  A[0,K]*B[K,3]
// K+5                                                                                                  A[1,K]*B[K,3]
// K+6                                                                                                                  A[2,K]*B[K,3]
// K+7                                                                                                                                  A[3,K]*B[K,3]

// Writing back to C could be performed after the completion of PE[0,0] / PE[3,3]
// Current implementation is the latter one, which is simpler
// FSM State    Cycle       Operation
// STATE_CALC   K+1 / -1    Finish calculating C[0,0]
// STATE_CALC   K+2 /  0    Set SRAM signal C[0,0]
// STATE_CALC   K+3 /  1    Set SRAM singal C[0,1]
// STATE_CALC   K+4 /  2    Set SRAM singal C[0,2]
// STATE_CALC   K+5 /  3    Set SRAM singal C[0,3]
// STATE_CALC   K+6 /  4    Set SRAM singal C[1,0]
// STATE_CALC   K+7 /  5    Set SRAM singal C[1,1]
// STATE_WRITE   0  /  6    Set SRAM signal C[1,2]
// STATE_WRITE   1  /  7    Set SRAM signal C[1,3]
// STATE_WRITE   2  /  8    Set SRAM signal C[2,0]
// STATE_WRITE   3  /  9    Set SRAM signal C[2,1]
// STATE_WRITE   4  / 10    Set SRAM signal C[2,2]
// STATE_WRITE   5  / 11    Set SRAM signal C[2,3]
// STATE_WRITE   6  / 12    Set SRAM signal C[3,0]
// STATE_WRITE   7  / 13    Set SRAM signal C[3,1]
// STATE_WRITE   8  / 14    Set SRAM signal C[3,2]
// STATE_WRITE   9  / 15    Set SRAM signal C[3,3]
// STATE_WRITE  10  / 16    Finish writing SRAM C[3,3]

// PE port
// in_top_buf_arr & in_left_buf_arr
generate
    for (idx=0; idx<4; idx=idx+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)                     in_left_buf_arr[idx][idx] <= 0;
            else if (not_finish_feedsig)    in_left_buf_arr[idx][idx] <= A_data_out[(3-idx)*8+7:(3-idx)*8];
            else                            in_left_buf_arr[idx][idx] <= 0;
        end
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)                     in_top_buf_arr[idx][idx] <= 0;
            else if (not_finish_feedsig)    in_top_buf_arr[idx][idx] <= B_data_out[(3-idx)*8+7:(3-idx)*8];
            else                            in_top_buf_arr[idx][idx] <= 0;
        end
    end
    for (idx=1; idx<4; idx=idx+1) begin
        for (idy=0; idy< idx; idy=idy+1) begin
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) in_left_buf_arr[idx][idy] <= 0;
                else        in_left_buf_arr[idx][idy] <= in_left_buf_arr[idx][idy+1];
            end
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) in_top_buf_arr[idx][idy] <= 0;
                else        in_top_buf_arr[idx][idy] <= in_top_buf_arr[idx][idy+1];
            end
        end
    end
endgenerate

// pe_reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) pe_reset <= 1;
    else        pe_reset <= finish_write;
end

// in_top_arr & in_left_arr
generate
    for (idx=0; idx<4; idx=idx+1) begin
        assign in_left_arr[idx][0] = in_left_buf_arr[idx][0];
    end
    for (idx=0; idx<4; idx=idx+1) begin
        for (idy=1; idy<4; idy=idy+1) begin
            assign in_left_arr[idx][idy] = out_right_arr[idx][idy-1];
        end
    end
    for (idy=0; idy<4; idy=idy+1) begin
        assign in_top_arr[0][idy] = in_top_buf_arr[idy][0];
    end
    for (idx=1; idx<4; idx=idx+1) begin
        for (idy=0; idy<4; idy=idy+1) begin
            assign in_top_arr[idx][idy] = out_bot_arr[idx-1][idy];
        end
    end
endgenerate

// PE systolic array module
generate
    for (idx=0; idx<4; idx=idx+1) begin
        for (idy=0; idy<4; idy=idy+1) begin
            PE pe(
                .clk        (clk),
                .rst_n      (rst_n),
                .reset      (pe_reset),
                .in_top     (in_top_arr     [idx][idy]),
                .in_left    (in_left_arr    [idx][idy]),
                .out_bot    (out_bot_arr    [idx][idy]),
                .out_right  (out_right_arr  [idx][idy]),
                .out_sum    (out_sum_arr    [idx][idy])
            );
        end
    end
endgenerate
endmodule

// Processing Element (output stationary)
module PE (
    clk,
    rst_n,

    reset,
    in_top,
    in_left,
    out_bot,
    out_right,
    out_sum
);

input clk;
input rst_n;

input reset;
input       [ 7:0]  in_top, in_left;
output reg  [ 7:0]  out_bot, out_right;
output reg  [31:0]  out_sum;

// ===============================================================
//                      Wire & Register
// ===============================================================

// ===============================================================
//                          Design
// ===============================================================
// Accumulated Sum
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     out_sum <= 0;
    else if (reset) out_sum <= 0;
    else            out_sum <= out_sum + in_top * in_left;
end

// Output Port
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     out_bot <= 0;
    // else if (reset) out_bot <= 0;
    else            out_bot <= in_top;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     out_right <= 0;
    // else if (reset) out_right <= 0;
    else            out_right <= in_left;
end

endmodule