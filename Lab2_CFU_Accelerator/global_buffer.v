//============================================================================//
// AIC2021 Project1 - TPU Design                                              //
// file: global_buffer.v                                                      //
// description: global buffer read write behavior module                      //
// authors: kaikai (deekai9139@gmail.com)                                     //
//          suhan  (jjs93126@gmail.com)                                       //
//============================================================================//
module global_buffer #(parameter ADDR_BITS=8, parameter DATA_BITS=8)(clk, wr_en, index, data_in, data_out);
  input clk;
  input wr_en; // Write enable: 1->write 0->read
  input      [ADDR_BITS-1:0] index;
  input      [DATA_BITS-1:0]       data_in;
  output reg [DATA_BITS-1:0]       data_out;

  integer i;

  parameter DEPTH = 2**ADDR_BITS;

//----------------------------------------------------------------------------//
// Global buffer (Don't change the name)                                      //
//----------------------------------------------------------------------------//
  // reg [`GBUFF_ADDR_SIZE-1:0] gbuff [`WORD_SIZE-1:0];
  // reg [DATA_BITS-1:0] gbuff [DEPTH-1:0];
  (*ram_style = "block"*) reg [DATA_BITS-1:0] gbuff [DEPTH-1:0];

//----------------------------------------------------------------------------//
// Global buffer read write behavior                                          //
//----------------------------------------------------------------------------//
  always @ (negedge clk) begin
    if(wr_en) begin
      gbuff[index] <= data_in;
    end
    else begin
      data_out <= gbuff[index];
    end
  end

endmodule