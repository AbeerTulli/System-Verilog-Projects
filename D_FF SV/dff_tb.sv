class transaction;
  //clock and rst will be taken care of in tb top.
  // here I work with other variables 
  
  rand bit din;
  bit dout;
  
  function transaction copy();
    copy = new();
    copy.din = this.din;
    copy.dout = this.dout;
  endfunction
  
  function void display(input string tag);
    $display("[%0s] : DIN : %0b, DOUT : %b", tag, din, dout);
  endfunction
  
endclass


class generator;
  transaction gen_t;
  mailbox #(transaction) gen2drv_mbx; // to send data to driver
  
  mailbox #(transaction) gen2ref_mbx; // to send reference data to scoreboard
  
  event sconext; //event to sense the completion of scoreboard work 
  event done; //event to trigger when the request number of stimuli is applied 
  int count; //stimulus count 
  
  function new (mailbox #(transaction) gen2drv_mbx, mailbox #(transaction) gen2ref_mbx);
    this.gen2drv_mbx = gen2drv_mbx;
    this.gen2ref_mbx = gen2ref_mbx;
    gen_t = new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(gen_t.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
      gen2drv_mbx.put(gen_t.copy); // so that we dont change the transaction file when we go between steps
      gen2ref_mbx.put(gen_t.copy);
      gen_t.display("GEN");
      @(sconext); //wait for scoreboards completion signal
    end
    -> done; // trigger done when all stimuli have been applied 
  endtask
  
endclass

class driver;
  
  transaction drv_t;
  mailbox #(transaction) drv_mbx; // to recieve data from generator 
  virtual dff_inf dif; //virtual : allows a class to access a DUT instance.
  
  function new(mailbox #(transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction
  
  task reset(); // because reset is also a dut input, and driver is responsible for the DUT inputs. 
    dif.rst <= 1'b1;
    repeat(5) @(posedge dif.clk); //wait for 5 clock cycles
    dif.rst <= 1'b0;
    @(posedge dif.clk); // wait for one more clock cycle
    $display("[DRV] : RESET DONE");//display reset completion message
  endtask
  
  task run();
    forever begin
      drv_mbx.get(drv_t);
      dif.din <= drv_t.din;
      @(posedge dif.clk);// wait for one clock cycle
      drv_t.display("DRV");
      dif.din <= 1'd0;
      @(posedge dif.clk); //wait for the rising edge of the clock.
    end
  endtask
  
endclass

class monitor;
  
  transaction mon_t;
  mailbox #(transaction) mon2sco_mbx;
  virtual dff_inf mif;
  
  function new(mailbox #(transaction) mon2sco_mbx);
    this.mon2sco_mbx = mon2sco_mbx;
  endfunction
  
  task run();
    mon_t = new(); //create new transaction
    forever begin
      repeat(2) @(posedge mif.clk); //wait for 2 rising edge of clock 
      mon_t.dout <= mif.dout;
      mon2sco_mbx.put(mon_t);
      mon_t.display("MON");
    end
  endtask
endclass

class scoreboard;
  
  transaction sco_t;
  transaction sco_tref;
  
  mailbox #(transaction) sco_mbx;
  mailbox #(transaction) sco_mbx_ref;
  
  event sconext;
  
  function new(mailbox #(transaction) sco_mbx, mailbox #(transaction) sco_mbx_ref);
    this.sco_mbx = sco_mbx;
    this.sco_mbx_ref = sco_mbx_ref;
  endfunction
  
  task run();
    forever begin
      sco_mbx.get(sco_t);
      sco_mbx_ref.get(sco_tref);
      
      sco_t.display("SCO");
      sco_tref.display("REF");
      
      if(sco_t.dout == sco_tref.din)
        $display("[SCO] : DATA MATCHED");
      else
        $display("[SCO] : DATA MISMATCHED");
      $display("-------------------------");
      ->sconext;
    end
  endtask
  
endclass

class environment;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event next;
  
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) mbxref;
  mailbox #(transaction) msmbx;
  
  virtual dff_inf vif;

  function new(virtual dff_inf vif);
    gdmbx = new();
    mbxref = new();
    msmbx = new();
    
    gen = new (gdmbx, mbxref);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx, mbxref);
    
    this.vif = vif;
    drv.dif = this.vif;
    mon.mif = this.vif;
    gen.sconext = next;
    sco.sconext = next; // sets the communication between scoreboard and generator
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
    join_any //will continue when any one of them finishes
  endtask
  
  task post_test();
    
    wait (gen.done.triggered); //wait for generator to complete
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
  
  dff_inf tif(); // need () for interface in module 
  
  dff dut(tif);
  
  initial begin
    tif.clk <= 0;
  end
  
  always #10 tif.clk <= ~tif.clk;
  
  environment env;
  
  initial begin
    env = new(tif);
    env.gen.count = 30;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd"); //specifiy the vcd dump file
    $dumpvars; //dump all variables 
  end 
endmodule
  
  
  
  
  
      
    
               
  
  