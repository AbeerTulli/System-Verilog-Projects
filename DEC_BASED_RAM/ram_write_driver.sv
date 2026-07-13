//ram_write_driver.sv
//Driver write transactions onto the DUT bus via wr_cb clocking block
// signals come back to wr_driver via wr_done_mbx.

`ifndef RAM_WRITE_DRIVER_SV
`define RAM_WRITE_DRIVER_SV

`include "ram_transaction.sv"
`include "ram_if.sv"

class ram_write_driver;
  
  virtual ram_if.WRITE_DRV vif; 
  //class is dyanamic in nature and interface is static in nature, and you cant use static nature interface inside dynamic class, hence we have used virtual
  
  mailbox #(ram_transaction) wr_mbx;
  
  mailbox #(bit) wr_done_mbx;
  
  int unsigned txn_count; // to count how many number of transactions i have
  
  //interface instance is created in the top module since the DUT also needs it 
  // it is passed to the env via new() method.
  // from env new() method we pass it to the driver via new()
  // (interface in top module ) -> test -> env -> driver
  
  function new(virtual ram_if.WRITE_DRV vif, 
               mailbox #(ram_transaction) wr_mbx, 
               mailbox #(bit) wr_done_mbx);
    
    this.vif = vif; // we connect the interface handle inside the driver to the interface declared in the top module 
    this.wr_mbx = wr_mbx;
    this.wr_done_mbx = wr_done_mbx;
    this.txn_count = 0;
    
  endfunction 
  
  task reset(int unsigned cycles = 4);
    
    $display("applying reset task");
    
    vif.rst_n <= 1'b0;
    vif.wr_cb.we <= 1'b0;
    vif.wr_cb.wr_addr <= 0;
    vif.wr_cb.wdata <= 0;
    
    repeat (cycles)@(vif.wr_cb); // repeat the task for however long the user wants
      
      vif.rst_n = 1'b1; 

      @(vif.wr_cb);
    $display("reset deasserted");
    
  endtask
  
  task drive(ram_transaction txn);
    
    @(vif.wr_cb);
    vif.wr_cb.we <= 1'b1;
    vif.wr_cb.wr_addr <= txn.addr; // txn handle is given by the generator 
    vif.wr_cb.wdata <= txn.wdata;
    
    @(vif.wr_cb);
    vif.wr_cb.we <= 1'b0;
    vif.wr_cb.wr_addr <= 0;
    vif.wr_cb.wdata <= 0;
    
  endtask
  
  task run(); //called by environment 
    ram_transaction txn; //no need to create object since we are going to get it from generator 
    
    forever begin
      wr_mbx.get(txn);
      drive(txn);
      txn_count++;
      wr_done_mbx.put(1'b1); // this will be given to generator 
    end
  endtask
  
endclass

`endif
