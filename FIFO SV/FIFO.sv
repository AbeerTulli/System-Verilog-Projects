module FIFO ( input clk, rst, wr, rd,
             input [7:0] din, output reg [7:0] dout,
             output empty, full);
  
  reg [3:0] wptr = 0, rptr = 0;
  reg [4:0] count = 0;
  reg [7:0] mem [15:0];
  
  always @(posedge clk)
    begin
      if(rst == 1'b1) begin
        wptr <= 0;
        rptr <= 0;
        count <= 0;
        dout <= 0;
      end
      
      else if ( wr && !full) begin
        mem[wptr] <= din;
        count <= count +1;
        wptr <= wptr +1;
      end
      
      else if (rd && !empty) begin
        dout <= mem[rptr];
        count <= count -1;
        rptr <= rptr+1;
      end
    end
  
  assign full = (count == 16) ? 1'b1 : 1'b0;
  assign empty = (count == 0) ? 1'b1 : 1'b0;
  
endmodule
    
interface fifo_inf;
  logic clk,rd,wr,full, empty;
  logic rst;
  logic [7:0] din;
  logic [7:0] dout;
endinterface