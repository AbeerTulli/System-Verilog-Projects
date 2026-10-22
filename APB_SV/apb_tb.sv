class transaction;
  
  rand bit [31:0] paddr;
  rand bit psel;
  rand bit pwrite;
  rand bit [7:0] pwdata;
  rand bit penable;
  // clock and reset we will directly generate in our driver
  
  // these are output ports, there we need to use bit,reg or logic type to declare a data member for them.
  bit [7:0] prdata;
  bit pready;
  bit pslverr;
  
  constraint con_addr {
    paddr >= 0; paddr <= 15;
  }
  
  constraint con_data {
    pwdata >= 0; pwdata <= 255; // 2^8
  }
  
  function void display (input string tag);
    $display("[%0s] : paddr : %0d, pwrite : %0d, pwdata : %0d, prdata : %0d, pslverr : %0b at %0t", tag, paddr, pwrite, pwdata, prdata, pslverr, $time); 
    //this is used to test the different operations of a test bench.
    
  endfunction
endclass

class generator;
  
  transaction gen_tr;
  mailbox #(transaction) gen_mbx;
  int count = 0; // number of random stimuli to be applied to our DUT
  
  event nextdrv; //driver completed task of triggering interfce.
  event nextsco; //scoreboard completed its objective
  event done; // when required number of stimuli have been sent
  
  function new (mailbox #(transaction) gen_mbx);
    this.gen_mbx = gen_mbx;
    gen_tr = new();
  endfunction
  
  task run();
    repeat (count) begin
      assert(gen_tr.randomize()) else $error("RANDOMIZATION FAILED !");
    gen_mbx.put(gen_tr);
    gen_tr.display("GEN");
    @(nextdrv); // wait for driver to complete its operation
    @(nextsco); // wait for scoreboard to complete its op.
    end
    ->done; // complete simulation when all stimuli tested. 
  endtask
  
endclass
///////////////////////////////

class driver;
  
  virtual apb_inf drv_inf;
  transaction drv_tr;
  mailbox #(transaction) drv_mbx;
  
  event nextdrv;
  
  function new(mailbox #(transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction
  
  task reset();
    drv_inf.prstn <= 1'b0;
    drv_inf.paddr <= 32'h0000;
    drv_inf.psel <= 1'b0;
    drv_inf.pwrite <= 1'b0;
    drv_inf.pwdata <= 8'h00;
    drv_inf.penable <= 1'b0;
    repeat(5) @(posedge drv_inf.pclk);
    drv_inf.prstn <= 1'b1;
    $display("[DRV] has been reset");
  endtask
  
  //now! lets run this shit
  task run();
    forever begin // this will continue from the begining to the end of the simulation
      
      drv_mbx.get(drv_tr);
      @(posedge drv_inf.pclk);
      if(drv_tr.pwrite == 1'b1) begin // it is a write operation. take the necessary steps
        drv_inf.paddr <= drv_tr.paddr;
        drv_inf.psel <= 1'b1;
 		drv_inf.pwrite <= 1'b1;
        drv_inf.pwdata <= drv_tr.pwdata;
        drv_inf.penable <= 1'b0;
        
        @(posedge drv_inf.pclk);
        drv_inf.penable = 1'b1;
        @(posedge drv_inf.pclk);
        drv_inf.psel <= 1'b0;
        drv_inf.penable <= 1'b0;
        drv_inf.pwrite <= 1'b0;
        drv_tr.display("DRV");
        ->nextdrv;
        // driver has completed its task
      end
      else if (drv_inf.pwrite == 1'b0) begin 
        drv_inf.paddr <= drv_tr.paddr;
        drv_inf.psel <= 1'b1;
        drv_inf.pwrite <= 1'b0;
        drv_inf.penable <= 1'b0;
        @(posedge drv_inf.pclk);
        drv_inf.penable <= 1'b1;
        @(posedge drv_inf.pclk);
        drv_inf.penable <= 1'b0;
        drv_inf.psel <= 1'b0;
        drv_tr.display("DRV");
        ->nextdrv;
      end
    end
    
  endtask
  
endclass

///////////////////////////////////////////
class monitor;
  
  virtual apb_inf mon_inf;// to capture response of DUT
  mailbox #(transaction) mon_mbx;
  transaction mon_tr;
  
  function new(mailbox #(transaction) mon_mbx);
    this.mon_mbx = mon_mbx;
    mon_tr = new();
  endfunction
  
  task run();
    forever begin // just like driver, it is executed forever
      @(posedge mon_inf.pclk); // for first cycle to complete
      if(mon_inf.pready) begin
        mon_tr.paddr = mon_inf.paddr;
        mon_tr.pwrite = mon_inf.pwrite;
        mon_tr.pwdata = mon_inf.pwdata;
        mon_tr.prdata = mon_inf.prdata;
        mon_tr.pslverr = mon_inf.pslverr;
        @(posedge mon_inf.pclk);
        // we have added this delay, since after penable becomes 1 in driver, out pready also becomes 1. and after that we have 1 more clock cycle in driver.
        mon_tr.display("MON");
        mon_mbx.put(mon_tr);
      end
    end
  endtask
  
endclass

////////////////////////////////////////////

class scoreboard;
  
  mailbox #(transaction) sco_mbx;
  transaction sco_tr;
  
  event nextsco;
  
  // to emulate the actual DUT, we have created a memory component.
  bit [7:0] sco_mem [0:15] = '{default: 0};
  bit [7:0] rdata = 0;
  int err = 0;
  
  function new(mailbox #(transaction) sco_mbx);
    this.sco_mbx = sco_mbx;
  endfunction
  
  
  task run();
    forever begin
      
      sco_mbx.get(sco_tr);
      sco_tr.display("SCO");
      
      if((sco_tr.pwrite == 1'b1) && (sco_tr.pslverr == 1'b0))
        begin
          sco_mem[sco_tr.paddr] = sco_tr.pwdata;
          // we are filling in the sco_mem
          $display("[SCO] : the data stored is :%d, in addr :%0d", sco_tr.pwdata, sco_tr.paddr);
        end
      else if ((sco_tr.pwrite == 1'b0) && (sco_tr.pslverr == 1'b0))
        begin
          rdata = sco_mem[sco_tr.paddr];
          if(rdata == sco_tr.prdata)
            $display("[SCO] : DATA MATCHED ");
          else begin
            err++;
            $display("[SCO] : DATA NOT MATCH :(");
          end
        end
      else if(sco_tr.pslverr == 1'b1)
        begin
          $display("[SCO] : there are error(s)");
          err++;
        end
      ->nextsco;
      
    end
  endtask
  
endclass
//////////////////////////////////////
class environment;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgen_drv;
  event nextgen_sco;
  
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) mon2sco;
  
  virtual apb_inf vif;
  
  function new(virtual apb_inf vif);
    
    gen2drv = new();
    mon2sco = new();
    
    gen = new(gen2drv);
    drv = new(gen2drv);
    
    mon = new(mon2sco);
    sco = new(mon2sco);
    
    this.vif = vif;
    drv.drv_inf = this.vif;
    mon.mon_inf = this.vif;
    
    gen.nextdrv = nextgen_drv;
    drv.nextdrv = nextgen_drv;
    
    gen.nextsco = nextgen_sco;
    sco.nextsco = nextgen_sco;
    
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
    $display(" TOTAL MISMATCH : %0d", sco.err);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
  
  apb_inf vif();
  
  apb_slave dut (
    vif.pclk, 
    vif.prstn,
    vif.paddr,
    vif.psel,
    vif.pwrite,
    vif.pwdata,
    vif.penable,
    vif.prdata,
    vif.pready,
    vif.pslverr
  );
    
  initial begin 
    vif.pclk = 0;
  end
  
  always #10 vif.pclk <= ~vif.pclk;
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 20;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule
    
                   
      
      
        
    
  

    
  
  
  
  

