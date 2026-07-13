// ram_read_monitor.sv
// It recieves each read request (with its address) from ram_read_driver via rd_done_mbx, in issue order.
// for every request it forwards a copy to reference model (for evaluation) and waits for DUT to assert "valid" and captures the actual rdata, then forwards the actual result to the scoreboard.

`ifndef RAM_READ_MONITOR_SV
`define RAM_READ_MONITOR_SV

`include "ram_transaction.sv"
`include "ram_if.sv"

class ram_read_monitor;
  
  virtual ram_if.RD_MON vif;
  
  mailbox #(ram_transaction) sb_rd_mbx; // -> scoreboard (actual)
  mailbox #(ram_transaction) rm_rd_mbx; // -> ref model (request)
  
  int unsigned observed_count;
  
  function new(virtual ram_if.RD_MON vif,
               mailbox #(ram_transaction) sb_rd_mbx,
               mailbox #(ram_transaction) rm_rd_mbx);
    this.vif = vif;
    this.sb_rd_mbx = sb_rd_mbx;
    this.rm_rd_mbx = rm_rd_mbx;
    this.observed_count = 0;
    
  endfunction
  
  task run();
    
    ram_transaction txn;
    
    forever begin
      @(posedge vif.clk); //waiting for the driver to prepare signals 
      #2;
      
      txn.rdata = vif.mon_cb.rdata;
      txn.valid = vif.mon_cb.valid;
      txn.valid = vif.mon_cb.re;
      
      if(txn.valid == 0) begin
        $display("valid not generated waiting for valid");
      end
      
      observed_count++;
      txn.print("rd_mon");
      
      sb_rd_mbx.put(txn);
      rm_rd_mbx.put(txn);
    end
  endtask
endclass

`endif
