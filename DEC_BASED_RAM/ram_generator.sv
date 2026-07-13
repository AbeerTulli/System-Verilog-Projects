 // ram generator.sv 

// generator builds transaction and pushes them to the write / read driver mailboxes. 
// it is called once per test.

`ifndef RAM_GENERATOR_SV
`define RAM_GENERATOR_SV

`include "ram_transaction.sv"

class ram_generator;
  
  //mailboxes ? private, enforced by compiler 
  local mailbox #(ram_transaction) wr_mbx;
  local mailbox #(ram_transaction) rd_mbx;
  local mailbox #(bit) wr_done_mbx;
  
  //constructor
  function new(mailbox #(ram_transaction) wr_mbx,
               mailbox #(ram_transaction) rd_mbx,
               mailbox #(bit) wr_done_mbx);
    this.wr_mbx = wr_mbx;
    this.rd_mbx = rd_mbx;
    this.wr_done_mbx = wr_done_mbx;
  endfunction
  
  local task send_write(input logic [6:0] addr, input logic [7:0] data);
    ram_transaction txn = new();
    txn.op = ram_transaction::WRITE;
    txn.addr = addr;
    txn.wdata = data;
    txn.print("[GEN-WR]");
    wr_mbx.put(txn);
  endtask
  
  local task wait_writes_done(input int unsigned n);
    bit tok;
    repeat(n) wr_done_mbx.get(tok);
  endtask
  
  local task send_read(input logic [6:0] addr);
    ram_transaction txn = new();
    txn.op = ram_transaction::READ;
    txn.addr = addr;
    txn.print("[GEN-RD]");
    rd_mbx.put(txn);
    endtask
  
  task run(
    input logic [6:0] wr_addrs [],
    input logic [7:0] wr_datas [],
    input int unsigned n_writes,
    input logic [6:0] rd_addrs [], 
    input int unsigned n_reads,
    input bit randomize_txns = 0);
    
    //---- WRITES------
    $display("[GEN] sending %0d writes", n_writes);
    if(randomize_txns) begin
      for (int unsigned i = 0; i < n_writes; i++) begin
        ram_transaction txn = new();
        if(!txn.randomize() with { op == WRITE; })
          $fatal(1, "[GEN] randomize() failed for WRITE %0d", i);
        send_write(txn.addr, txn.wdata);
      end
    end else begin
      for(int unsigned i = 0; i < n_writes; i++)
        send_write(wr_addrs[i], wr_datas[i]);
    end
    
    //drain all writes before issuing reads 
    wait_writes_done(n_writes);
    $display("[GEN] All writes done");
    
    //reads
    $display("[GEN] sending %0d reads", n_reads);
    if(randomize_txns) begin
      for(int unsigned i = 0; i < n_reads; i++) begin
        ram_transaction txn = new();
        if(!txn.randomize() with {op == READ;})
          $fatal(1, "[GEN] randomize() failed for READ %0d", i);
        send_read(txn.addr);
      end
    end else begin
      for(int unsigned i = 0; i<n_reads; i++)
        send_read(rd_addrs[i]);
    end
    
    $display("[GEN] Done");
    endtask
  
endclass : ram_generator

`endif
