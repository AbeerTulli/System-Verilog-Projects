//ram_read_driver.sv 
//drives read transactions onto the DUT but via rd_cb. 
//after issuing a read, it forwards a copy of the request (with its addr) into rd_done_mbx so ram_read_monitor knows what was requested.

`ifndef RAM_READ_DRIVER_SV
`define RAM_READ_DRIVER_SV 

`include "ram_transaction.sv"
`include "ram_if.sv"


class ram_read_driver;
  virtual ram_if.READ_DRV vif;
  
  mailbox #(ram_transaction) rd_mbx;
  mailbox #(ram_transaction) rd_done_mbx;
  
  int unsigned txn_count;
  
  function new(virtual ram_if.READ_DRV vif,  // we dont pass these parameters in case of UVM
               mailbox #(ram_transaction) rd_mbx, 
               mailbox #(ram_transaction) rd_done_mbx);
    
    this.vif = vif;
    this.rd_mbx = rd_mbx;
    this.rd_done_mbx = rd_done_mbx;
    
  endfunction
  
  task drive(ram_transaction txn);
    @(vif.rd_cb); //we are waiting for this clocking block 
    vif.rd_cb.re <= 1'b1;
    vif.rd_cb.rd_addr <= txn.addr;
    
    @(vif.rd_cb)
    
    vif.rd_cb.re <= 1'b0;
    vif.rd_cb.rd_addr <= 7'h00;
    
  endtask
  
  task run();
    ram_transaction txn;
    
    forever begin
      rd_mbx.get(txn);
      drive(txn);
      txn_count++;
      
    end
  endtask
endclass

`endif
