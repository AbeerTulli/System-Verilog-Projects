//ram_ref_model.sv

//so the reference model is fed by write_monitor and read_monitor 

`ifndef RAM_REF_MODEL
`define RAM_REF_MODEL

`include "ram_transaction.sv"
`include "ram_if.sv"

class ram_ref_model;
  
  logic [7:0] mem[0:127];
  // [7:0] - packed dimension - element is 8 bits wide - 7 MSB to 0 LSB.
  // [0:127] - unpacked dimension - 128 elements indexed from 0 to 127. ie mem[0] is the first memory location.
  
  
  mailbox #(ram_transaction) rm_wr_mbx;
  mailbox #(ram_transaction) rm_rd_mbx;
  mailbox #(ram_transaction) sb_exp_mbx; // scoreboard - expected
  
  int unsigned wr_processed;
  int unsigned rd_processed;
  
  function new (mailbox #(ram_transaction) rm_wr_mbx,
                mailbox #(ram_transaction) rm_rd_mbx,
                mailbox #(ram_transaction) sb_exp_mbx);
    
    this.rm_wr_mbx = rm_wr_mbx;
    this.rm_rd_mbx = rm_rd_mbx;
    this.sb_exp_mbx = sb_exp_mbx;
    
    foreach(mem[i])
      mem[i] = 8'h00;
    
    wr_processed = 0;
    rd_processed = 0;
    
  endfunction
  
  task run_writes(); // to write the data into the reference model 
    
    ram_transaction txn;
    
    $display("[RM] write task started");	 
    
    forever begin
      rm_wr_mbx.get(txn);
      mem[txn.addr] = txn.wdata; // this txn packet is coming from mailbox attached to monitor
      
      wr_processed++;
      
      $display("[RM] wr addr = %0h data is %0h block %0d", txn.addr, txn.wdata,txn.addr[6:5]);
      
    end
  endtask
  
  task run_reads();
    
    ram_transaction txn;
    
    $display("[RM] read task started");
    
    forever begin
      rm_rd_mbx.get(txn);
      txn.wdata = mem[txn.addr];
      txn.valid = 1'b1;
      
      rd_processed++;
    end
      
  endtask
      
endclass
                                                                                              
`endif                                                                    
