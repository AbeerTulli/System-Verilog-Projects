class transaction; // it will have all the DUT signals other than global signals 
  
  rand bit op; // if 1 : wr, 0 : rd
  bit rd, wr;
  bit [7:0] din;
  bit full, empty;
  bit [7:0] dout;
  
  constraint op_con{ // constraint MUST have a name
    op dist{1:/50, 0:/ 50};
  }
  //we havent implemented deep copy, since we will be doing in order execution for FIFO.
  
  // in-order TB: DUT processes signals in the same order they are sent.
  //  for eg: FIFO, simple APB transactions.
  //  scoreboard can compare :: expected[0] ↔ actual[0], expected[1] ↔ actual[1], etc.
  
  // out-of-order TB: DUT may return results in a different order.
  // Example: AXI with multiple outstanding transactions, pipelined systems.
  // Scoreboard needs to identify which expected transaction corresponds to each actual transaction (usually using an ID/tag).
  // Deep copies are often needed because multiple transactions may be stored and modified independently.
  
endclass

//////////////////////////////////////////

class generator; // randomise stimulus to send to driver.
  
  transaction gen_tr;
  mailbox #(transaction) gen_mbx;
  int count = 0; // to be overwritten in tb;
  int i = 0;
  event next; // to be triggered when one transaction has been successfully sent
  event done; // to be triggered when all transactions have been successfully sent.
  
  function new(mailbox #(transaction) gen_mbx);
    this.gen_mbx = gen_mbx;
 
  endfunction 
  
  task run();
    repeat (count) begin
      gen_tr = new();
      // we need an object of transaction, since we will be PUTTING it in the mailbox 
      assert (gen_tr.randomize) else $error("Randomization failed :(");
      i++;
      gen_mbx.put(gen_tr);
      $display("[GEN] : operation : %0d, iteration : %0d", gen_tr.op, i);
      @(next);
    end
    
    -> done;
  endtask
    
endclass

///////////////////////////////////////////////

class driver;
  virtual fifo_inf drv_inf; // virtual , since interface is a static hardware construct whereas driver is a class ( dynamic object)
  
  mailbox #(transaction) drv_mbx;
 
  transaction drv_tr;
  
  event next;
  
  function new(mailbox #(transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction
  
  task reset();
    drv_inf.rst <= 1'b1;
    drv_inf.rd <= 1'b0;
    drv_inf.wr <= 1'b0;
    drv_inf.din <= 0; // we cant define output of an interface like this.
    repeat (5) @(posedge drv_inf.clk);
    drv_inf.rst <= 1'b0;
    $display("[DRV] : DUT Reset Done");
    $display("-------------------------");
  endtask
  
  task write();
    @(posedge drv_inf.clk) // we have not written always , since we dont want it to repeat forever. 
    // here it will happen ONCE. AT posedge of clk
    drv_inf.rst <= 1'b0;
    drv_inf.wr <= 1'b1;
    drv_inf.rd <= 1'b0;
    drv_inf.din <= $urandom_range(1,10);
    @(posedge drv_inf.clk);
    drv_inf.wr <= 1'b0;
    $display("[DRV] : DATA WRITE data : %0d", drv_inf.din);
    @(posedge drv_inf.clk);
  endtask
  
  
  task read();
    @(posedge drv_inf.clk);
    drv_inf.rst <= 1'b0;
    drv_inf.wr <= 1'b0;
    drv_inf.rd <= 1'b1;
    @(posedge drv_inf.clk);
    drv_inf.rd <= 1'b0;
    $display(" [DRV] : DATA READ"); // cant display read data since, dout will be handled by monitor
    @(posedge drv_inf.clk);
  endtask
  
  ///// RUN
  task run();
    forever begin
      drv_mbx.get(drv_tr);
      if(drv_tr.op == 1'b1)
        write();
      else
        read();
    end
  endtask
  
endclass
//////////////////////////////////////

class monitor;
  
  virtual fifo_inf mon_inf;
  mailbox #(transaction) mon_mbx;
  
  transaction mon_tr;
  
  function new (mailbox #(transaction) mon_mbx);
    this.mon_mbx = mon_mbx;
  endfunction
  
  task run();
    forever begin
      mon_tr = new(); // ::: diff
      repeat (2) @(posedge mon_inf.clk); // since we need the driver to complete sending data to DUT
      mon_tr.wr = mon_inf.wr;
      mon_tr.rd = mon_inf.rd;
      mon_tr.din = mon_inf.din;
      mon_tr.full = mon_inf.full;
      mon_tr.empty = mon_inf.empty;
      mon_tr.op = mon_inf.wr;
      @(posedge mon_inf.clk); // to be symmetric to driver, with 3 clock cycles
      mon_tr.dout = mon_inf.dout;
      
      mon_mbx.put(mon_tr);
      
      $display("[MON] : Wr : %0d, rd: %0d, din: %0d, dout: %0d, full: %0d, empty: %0d", mon_tr.wr,mon_tr.rd,mon_tr.din,mon_tr.dout, mon_tr.full,mon_tr.empty);
    end
  endtask
  
endclass

class scoreboard;
  
  mailbox #(transaction) sco_mbx;
  
  transaction sco_tr;
  
  event next;
  
  bit [7:0] sco_din[$]; // we have added a queue. we will be comparing the results with the values in this queue. 
  bit [7:0] temp;
  int err = 0; // to store the number of errors we encounter during runtime.
  
  function new (mailbox #(transaction) sco_mbx);
    this.sco_mbx = sco_mbx;
  endfunction
  
  task run();
    forever begin
      
      sco_mbx.get(sco_tr);
      $display("[SCO] : Wr : %0d, rd: %0d, full: %0d, empty : %0d, din: %0d, dout : %0d", sco_tr.wr, sco_tr.rd, sco_tr.full, sco_tr.empty, sco_tr.din, sco_tr.dout );
      
      if(sco_tr.op == 1'b1) begin// write operation
        
        if(sco_tr.full == 1'b0) begin
          sco_din.push_front(sco_tr.din);
          $display("[SCO] stored data in queue : %0d", sco_tr.din);
        end
        else begin
          $display("[SCO] failed to store data, FIFO is FULL :(");
        end
        
      end
      
      if (sco_tr.op == 1'b0) begin
        
        if(sco_tr.empty == 1'b0) begin
          
          temp = sco_din.pop_back();
          
          if(sco_tr.dout == temp)
            $display("[SCO] : DATA MATCH");
          else begin
            $display("[SCO] : DATA MISMATCH !!");
            err++;
          end
        end
        else 
          begin
            $display("FIFO IS EMPTY");
          end
      end
      -> next; // this tells the generator to send next transaction
      
    end
  endtask
endclass

///////////////////////////////////////////////

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox #(transaction) gen2drv_mbx;
  mailbox #(transaction) mon2sco_mbx;
  
  event next_gen_sco;
  
  virtual fifo_inf fif;
    
  function new(virtual fifo_inf fif);
    gen2drv_mbx = new();
    gen = new(gen2drv_mbx); 
    // new constructor, makes a NEW instance of gen. and since gen already has a custom constructor in it. it connects the mailbox for both gen and drv
    drv = new(gen2drv_mbx);
    mon2sco_mbx = new();
    mon = new(mon2sco_mbx);
    sco = new(mon2sco_mbx);
    this.fif = fif;
    drv.drv_inf = this.fif;
    mon.mon_inf = this.fif;
    gen.next = next_gen_sco;
    sco.next = next_gen_sco;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork 
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $display("----------------------------");
    $display("Error Count :%0d", sco.err);
    $display("----------------------------");
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

////////////////////////////////////////
module tb;
  
  fifo_inf fif(); // in the module interface is instantiated as ();
  
  FIFO dut (.clk   (fif.clk), .rst   (fif.rst), .wr    (fif.wr), .rd    (fif.rd), .din   (fif.din), .dout  (fif.dout), .empty (fif.empty), .full  (fif.full));
  
  initial begin 
    fif.clk <= 0;
  end
  
  always #10 fif.clk <= ~fif.clk;
  
  environment env;
  
  initial begin
    env = new(fif);
    env.gen.count = 10;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule 
  
  

          
  


      
    
  
    
    
    