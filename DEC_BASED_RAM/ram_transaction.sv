//ram_transaction.sv
//randomizable transaction items are passed between all the TB components using this file 

  `ifndef RAM_TRANSACTION_SV
  `define RAM_TRANSACTION_SV 

  class ram_transaction;

    typedef enum {WRITE, READ} op_t;

    // only the inputs are randomized not the outputs
    rand op_t op;
    rand logic [6:0] addr;
    rand logic [7:0] wdata; 
    logic [7:0] rdata;
    logic valid;

    function new (); //constructor 
      // every class has a constructor, it runs whenever tr = new(); is executed 
      // ie an instance is created 
      op = WRITE;
      addr = 7'h00;
      wdata = 8'h00;
      rdata = 8'h00;
      valid = 1'b0;
      // we have declared the default values
    endfunction

  
    function ram_transaction copy(); // ram_transaction is the return type. ie function returns a ram_transaction object 
      ram_transaction t = new(); // we have made another instance of ram_transaction called t.
      t.op = this.op; // the value of op in t instance is made same as the value in the object it is called. 
      t.addr = this.addr;
      t.wdata = this.wdata;
      t.rdata = this.rdata;
      t.valid = this.valid;
      return t; // it returns the new instance formed
    endfunction

    function void print(string tag = "");
      $display("%0t : %s | op = %s addr = %0h wdata = %0h rdata = %0h valid = %0b", $time, tag, op.name(), addr, wdata, rdata, valid);
    endfunction

  endclass : ram_transaction

  `endif

