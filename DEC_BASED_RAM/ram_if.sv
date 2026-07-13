// making an interface is the first step to making the UVM  


`ifndef RAM_IF_SV
`define RAM_IF_SV 

interface ram_if(input clk);
   
  logic rst_n;
  logic re;
  logic we;
  logic	[6:0] wr_addr; // driven only by write driver 
  logic [6:0] rd_addr; //driven only by read driver 
  logic [6:0] addr; //muxed address actually sent to the DUT
  logic [7:0] wdata;
  logic [7:0] rdata;
  logic valid;
  
  // addr is decided through a mux, that chooses between wr_addr and  rd_addr 
  // this is done in the driver
  // we/re are never asserted in the same cycle by construction ( generator always finishes all writes before read op. 
  // this ensure that the mux doesnt have to arbitrate a real conflict
  
  assign addr = re ? rd_addr : wr_addr;
  
  // now lets implement clocking blocks 
  //clocking block of write DRIVER 
  
  clocking wr_cb @(posedge clk);
    default input #1 output #1; //declaring skew
    output we;
    output wr_addr;
    output wdata;
    input rdata;
    input valid;
  endclocking 
  
  //clocking block for read driver 
  clocking rd_cb @(posedge clk);
    default input #1 output #1;
    output re; 
    output rd_addr;	
    input rdata;
    input valid;
  endclocking
  
  //clocking block for monitor 
  clocking mon_cb @(posedge clk);
    default input #1; // since it is only sampling therefore input skew
    input we;
    input re;
    input addr;
    input wdata;
    input rdata;
    input valid;
  endclocking
  
  modport WRITE_DRV (clocking wr_cb, output rst_n, input clk); // write driver functions by wr_cb clocking block and it controls the rst_n. it decides when the dut resets, since it is WRITING. it generates rst_n.
    modport READ_DRV (clocking rd_cb, input rst_n, input clk); // the read driver simply watches the rst_n, since it is READING from the DUT. 
      modport WR_MON (clocking mon_cb, input rst_n , input clk);
        modport RD_MON ( clocking mon_cb, input rst_n, input clk);
          
 endinterface : ram_if
`endif
