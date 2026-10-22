module dff(dff_inf dif);
  
  always @(posedge dif.clk) begin
    if(dif.rst) 
      dif.dout <= 1'b0;
    else
      dif.dout <= dif.din;
  end
     
endmodule 

interface dff_inf;
  logic clk;
  logic rst;
  logic din;
  logic dout;
  
endinterface