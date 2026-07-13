//ram_write_monitor.sv
//samples the write bus on mon_cb. 
//every observed write is forworded to the reference model(to update memory) and to the score board's write sink(for bookkeeping)

`ifndef RAM_WRITE_MONITOR_SV
`define RAM_WRITE_MONITOR_SV

`include "ram_transaction.sv"
`include "ram_if.sv"

class ram_write_monitor;
  
  virtual ram_if.WR_MON vif;
  
  mailbox #(ram_transaction) sb_wr_mbx;
  
  mailbox #(ram_transaction) rm_wr_mbx;
  
  int unsigned observed_count;
  
  function new(virtual ram_if.WR_MON vif,
               mailbox #(ram_transaction) sb_wr_mbx,
               mailbox #(ram_transaction) rm_wr_mbx);
    
    this.vif = vif;
    this.sb_wr_mbx = sb_wr_mbx;
    this.rm_wr_mbx = rm_wr_mbx;
    this.observed_count = 0;
    
  endfunction
  
  task run();
    
    ram_transaction txn;
    $display("WR_MON started");
    
    forever begin 
      @(vif.mon_cb);
      
      if(vif.mon_cb.we == 1'b1) // extracting information from the interface to my write monitor 
        begin
          txn = new();
          txn.op = ram_transaction::WRITE;
          
          txn.addr = vif.mon_cb.addr;
          txn.wdata = vif.mon_cb.wdata;
          txn.valid = 1'b0;
          
          observed_count++;
          
          txn.print("wr_mon");
          
          sb_wr_mbx.put(txn.copy()); // we are giving the scoreboard and reference model, their own seperate copy. 
          rm_wr_mbx.put(txn.copy()); // so that changes made by one dont affect the other. :)
        end
    end
  endtask
endclass

`endif
