`timescale 1ns / 1ps


interface ahb_if;

  logic clk;
  logic [31:0] hwdata;
  logic [31:0] haddr;
  logic [2:0] hsize;
  logic [2:0] hburst;
  logic hresetn, hsel, hwrite;
  logic [1:0] htrans;
  logic [1:0] hresp;
  logic hready;
  logic [31:0] hrdata;

  logic [31:0] transfer_addr;


endinterface
///////////////////////////////////////////////


class ahb_transaction;

  rand bit [4:0] burst_length;
  rand bit [31:0] hwdata;
  rand bit [31:0] haddr;
  rand bit [2:0]  hsize;
  rand bit [2:0]  hburst;
  bit hresetn;
  rand bit hwrite;
  bit [1:0] htrans;
  bit [1:0] hresp;
  bit hready;
  bit [31:0] hrdata;

  constraint write_c {
    hwrite dist {1 :/ 1, 0:/ 1};
  }

  constraint ulen_c {
    burst_length == 5;
  }


  constraint burst_c {
  hburst == 6;
  }

  constraint addr_c {
  haddr == 5;
  }

  function ahb_transaction copy();
    copy = new();
    copy.hwdata = this.hwdata;
    copy.haddr  = this.haddr;
    copy.hsize  = this.hsize;
    copy.hburst = this.hburst;
    copy.hwrite = this.hwrite;
    copy.htrans = this.htrans;
    copy.hresp  = this.hresp;
    copy.hready = this.hready;
    copy.hrdata = this.hrdata;
    copy.burst_length   = this.burst_length;
  endfunction

 endclass


//////////////////////////////////////////////////////

class ahb_generator;

  ahb_transaction trans;

  mailbox #(ahb_transaction) gen_to_drv_mbx;

  mailbox #(bit [4:0]) gen_to_mon_len_mbx;


  event done;
  event driver_next;
  event scoreboard_next;

   int count = 0;


  function new( mailbox #(ahb_transaction) gen_to_drv_mbx, mailbox #(bit[4:0]) gen_to_mon_len_mbx);
    this.gen_to_drv_mbx = gen_to_drv_mbx;
    this.gen_to_mon_len_mbx = gen_to_mon_len_mbx;
    trans =new();
  endfunction


    task run();

   repeat(count) begin
      assert(trans.randomize) else $error("Randomization Failed");
      $display("[GEN] : DATA SENT TO DRV");
      gen_to_drv_mbx.put(trans.copy);
      gen_to_mon_len_mbx.put(trans.burst_length);
      @(driver_next);
      @(scoreboard_next);
    end

    ->done;
  endtask


endclass
///////////////////////////////////////////////////////


class ahb_driver;

  virtual ahb_if bus_if;

  ahb_transaction trans;

  event driver_next;

  mailbox #(ahb_transaction) gen_to_drv_mbx;


  function new( mailbox #(ahb_transaction) gen_to_drv_mbx );
    this.gen_to_drv_mbx = gen_to_drv_mbx;
  endfunction

  task reset();
    bus_if.hresetn <= 1'b0;
    bus_if.hwdata  <= 0;
    bus_if.haddr   <= 0;
    bus_if.hsize   <= 0;
    bus_if.hwrite  <= 0;
    bus_if.hsel    <= 0;
    bus_if.htrans  <= 0;
    repeat(10) @(posedge bus_if.clk);
    bus_if.hresetn <= 1'b1;
    $display("[DRV] : RESET DONE");
  endtask

  /////////////////////////////single transfer write

  task single_tr_wr();

   @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b000;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;

   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
   ->driver_next;
   $display("[DRV] : SINGLE TRANSFER WRITE ADDR : %0d DATA : %0d", trans.haddr, bus_if.hwdata);


  endtask

  ///////////////////////////////Single transfer read
 task single_tr_rd();

   @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b000;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;

   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
   ->driver_next;
   $display("[DRV] : SINGLE READ TRANSFER ADDR : %0d DATA : %0d", trans.haddr, bus_if.hwdata);

  endtask


  ///////////////////////// unspec length

  task unspec_len_wr();
    @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b001;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00; ///non seq


   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
    $display("[DRV] : UNSPEC LEN TRANSFER DATA : %0d ADDR : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(trans.burst_length - 1) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;    ///seq
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    $display("[DRV] : UNSPEC LEN TRANSFER  ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
    end

   ->driver_next;
  endtask

  ////////////////////////////////////////////unspec len read
    task unspec_len_rd();
    @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b001;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00; ///non seq


   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
    $display("[DRV] : UNSPEC LEN TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(trans.burst_length - 1) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;    ///seq

    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    $display("[DRV] : UNSPEC LEN TRANSFER  ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
    end

   ->driver_next;
  endtask



  ////////////////////////Increment 4 beats

  task incr4_wr ();
   $display("[DRV] : INCR4 WRITE");
   @(posedge bus_if.clk);
   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b011;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
   //$display("[DRV] : INCR4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
   @(posedge bus_if.hready);
   @(posedge bus_if.clk);

    repeat(3) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;
   // $display("[DRV] : INCR4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    end

   ->driver_next;
  endtask


  ///////////////////////////INCR4 read
    task incr4_rd ();
   $display("[DRV] : INCR4 READ");
   @(posedge bus_if.clk);
   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b011;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
  // $display("[DRV] : INCR4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
   @(posedge bus_if.hready);
   @(posedge bus_if.clk);

    repeat(3) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;
   // $display("[DRV] : INCR4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    end
   ->driver_next;
  endtask


  /////////////////////////Increment 8 beats

    task incr8_wr();
    @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b101;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;

   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
    $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);


    repeat(7) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;
    $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    end
  ->driver_next;
  endtask


  /////////////////////////////////INCR8 read
   task incr8_rd ();
    @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b101;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
   $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

   @(posedge bus_if.hready);
   @(posedge bus_if.clk);

    repeat(7) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;
     @(posedge bus_if.hready);
    @(posedge bus_if.clk);
     $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask


  ////////////////////////////////Increment 16 beats

   task incr16_wr();

   @(posedge bus_if.clk);
   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b111;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
      $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(15) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;
      @(posedge bus_if.hready);
    @(posedge bus_if.clk);
     $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask


  ////////////////////////////////////INCR 16 RD
  task incr16_rd();

   @(posedge bus_if.clk);
   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b111;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
      $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);


     repeat(15) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
     $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask



  //////////////////////////////////Wrap 4 beats

  task wrap4_wr();
   @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b010;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;

    @(posedge bus_if.hready);
   @(posedge bus_if.clk);
    $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(3) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;
      @(posedge bus_if.hready);
    @(posedge bus_if.clk);
     $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
   ->driver_next;
  endtask


  ///////////////////////////////////wrap4_rd

    task wrap4_rd();
   @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b010;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
    @(posedge bus_if.hready);
   @(posedge bus_if.clk);
     $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);


    repeat(3) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;
     @(posedge bus_if.hready);
    @(posedge bus_if.clk);
     $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
   ->driver_next;
  endtask


  ///////////////////////////////////Wrap 8 beats write

   task wrap8_wr();
     @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b100;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
    @(posedge bus_if.hready);
   @(posedge bus_if.clk);
     $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(7) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;
     @(posedge bus_if.hready);
    @(posedge bus_if.clk);
       $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask

  
  /////////////////////////////////wrap 8 read
     task wrap8_rd();
     @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b100;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
      $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(7) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;
      @(posedge bus_if.hready);
    @(posedge bus_if.clk);
      $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask

  ///////////////////////////////////////wrap 16 beats write

   task wrap16_wr();
     @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b110;

   bus_if.hwrite <= 1'b1;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= $urandom_range(1,50);
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
    @(posedge bus_if.hready);
   @(posedge bus_if.clk);
     $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

     repeat(15) begin
    bus_if.hwdata <= $urandom_range(1,50);
    bus_if.htrans  <= 2'b01;
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
      $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask

  
  //////////////////////////wrap 16 read

     task wrap16_rd();

     @(posedge bus_if.clk);

   bus_if.hresetn <= 1'b1;

   bus_if.hburst <= 3'b110;

   bus_if.hwrite <= 1'b0;
   bus_if.hsel   <= 1'b1;

   bus_if.hwdata <= 0;
   bus_if.haddr  <= trans.haddr;
   bus_if.hsize  <= 3'b010; //////write 4 byte

   bus_if.htrans <= 2'b00;
   @(posedge bus_if.hready);
   @(posedge bus_if.clk);
     $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    repeat(15) begin
    bus_if.hwdata <= 0;
    bus_if.htrans  <= 2'b01;
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
     $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", bus_if.hwdata, bus_if.haddr);

    end
  ->driver_next;
  endtask

/////////////////////////////////////////////////////////////////////


  task run();
    forever begin
    gen_to_drv_mbx.get(trans);

    if(trans.hwrite == 1'b1) begin
    case(trans.hburst)
      3'b000: single_tr_wr();
      3'b001: unspec_len_wr();
      3'b010: wrap4_wr();
      3'b011: incr4_wr();
      3'b100: wrap8_wr();
      3'b101: incr8_wr();
      3'b110: wrap16_wr();
      3'b111: incr16_wr();
    endcase
    end
   else begin
      case(trans.hburst)
      3'b000: single_tr_rd();
      3'b001: unspec_len_rd();
      3'b010: wrap4_rd();
      3'b011: incr4_rd();
      3'b100: wrap8_rd();
      3'b101: incr8_rd();
      3'b110: wrap16_rd();
      3'b111: incr16_rd();
    endcase
   end

  end
  endtask


endclass

///////////////////////////////////////////////////////////////////////////////////////

class ahb_monitor;

  virtual ahb_if bus_if;
  ahb_transaction trans;

  int len = 0;
  bit [4:0] observed_burst_length;

  mailbox #(ahb_transaction) mon_to_sco_mbx;
  mailbox #(bit[4:0]) gen_to_mon_len_mbx;

  function new( mailbox #(ahb_transaction) mon_to_sco_mbx, mailbox #(bit[4:0]) gen_to_mon_len_mbx);
    this.mon_to_sco_mbx = mon_to_sco_mbx;
    this.gen_to_mon_len_mbx = gen_to_mon_len_mbx;
  endfunction

  ///////////////////////////////////Single transfer
  ////////////////////////////////Write Operation
  task single_tr_wr();
  @(posedge bus_if.hready);
  @(posedge bus_if.clk);
  trans.haddr  = bus_if.haddr;
  trans.hwdata = bus_if.hwdata;
  trans.hwrite = 1;
  mon_to_sco_mbx.put(trans);
  $display("[MON]: SINGLE TRANSFER WRITE addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
  @(posedge bus_if.clk);
  endtask

  ///////////////////////////////Read Operation
  task single_tr_rd();
  @(posedge bus_if.hready);
  @(posedge bus_if.clk);
  trans.haddr  = bus_if.haddr;
  trans.hwrite = 0;
  trans.hrdata = bus_if.hrdata;
  mon_to_sco_mbx.put(trans);
 $display("[MON]: SINGLE TRANSFER READ addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
 @(posedge bus_if.clk);
  endtask

 
 ///////////////////////unspec len write
  task unspec_tr_wr();
    gen_to_mon_len_mbx.get(observed_burst_length);
    repeat(observed_burst_length) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: UNSPECWR addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask


 //////////////////////////unspec len read
    task unspec_tr_rd();
    gen_to_mon_len_mbx.get(observed_burst_length);
    repeat(observed_burst_length) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: UNSPECRD addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask

 ////////////////////////////////INCR 4 WRITE
   task incr4_wr();
   $display("[MON] : INCR4 DATA WRITE");
    repeat(4) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask


 ///////////////////////////////INCR 4 READ

    task incr4_rd();
    $display("[MON] : INCR4 DATA READ");
    repeat(4) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask


 ////////////////////////////wrap 4 write
 task wrap4_wr();
   $display("[MON] : WRAP4 DATA WRITE");
    repeat(4) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask


 ////////////////////wrap 4 read
   task wrap4_rd();
    $display("[MON] : WRAP4 DATA READ");
    repeat(4) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask


 ////////////////////////////////INCR 8 WRITE
   task incr8_wr();
   $display("[MON] : INCR8 DATA WRITE");
    repeat(8) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask


 ///////////////////////////////INCR 8 READ

    task incr8_rd();
    $display("[MON] : INCR8 DATA READ");
    repeat(8) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask


 ////////////////////////////wrap 8 write
 task wrap8_wr();
   $display("[MON] : WRAP8 DATA WRITE");
    repeat(8) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask


 ////////////////////wrap 8 read
   task wrap8_rd();
    $display("[MON] : WRAP8 DATA READ");
    repeat(8) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask

 ////////////////////////////////INCR 16 WRITE
   task incr16_wr();
   $display("[MON] : INCR16 DATA WRITE");
    repeat(16) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask

 
 ///////////////////////////////INCR 4 READ

    task incr16_rd();
    $display("[MON] : INCR16 DATA READ");
    repeat(16) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask


 ////////////////////////////wrap 16 write
 task wrap16_wr();
   $display("[MON] : WRAP16 DATA WRITE");
    repeat(16) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwdata = bus_if.hwdata;
    trans.hwrite = 1;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hwdata);
    @(posedge bus_if.clk);
    end
 endtask

 
 ////////////////////wrap 16 read
   task wrap16_rd();
    $display("[MON] : WRAP4 DATA READ");
    repeat(16) begin
    @(posedge bus_if.hready);
    @(posedge bus_if.clk);
    trans.haddr  = bus_if.transfer_addr;
    trans.hwrite = 0;
    trans.hrdata = bus_if.hrdata;
    mon_to_sco_mbx.put(trans);
    $display("[MON]: addr : %0d reference_mem : %0d", trans.haddr, trans.hrdata);
    @(posedge bus_if.clk);
    end
 endtask
 ///////////////////////////////////////////////////////////////


  ////////////////////////////////////////////////////////////////////////////
  task run();
    trans = new();
    forever begin
        @(posedge bus_if.clk);

        if(bus_if.hresetn && bus_if.hsel && bus_if.hwrite)
          begin
          case(bus_if.hburst)
          3'b000: single_tr_wr();
          3'b001: unspec_tr_wr();
          3'b010: wrap4_wr();
          3'b011: incr4_wr();
          3'b100: wrap8_wr();
          3'b101: incr8_wr();
          3'b110: wrap16_wr();
          3'b111: incr16_wr();
          endcase
          end


       if(bus_if.hresetn && bus_if.hsel && (bus_if.hwrite == 0))
          begin
          case(bus_if.hburst)
          3'b000: single_tr_rd();
          3'b001: unspec_tr_rd();
          3'b010: wrap4_rd();
          3'b011: incr4_rd();
          3'b100: wrap8_rd();
          3'b101: incr8_rd();
          3'b110: wrap16_rd();
          3'b111: incr16_rd();
          endcase
          end

      end


  endtask

endclass

////////////////////////////////////////////////////////////////////////////

class ahb_scoreboard;

  ahb_transaction trans;
  event scoreboard_next;

  mailbox #(ahb_transaction) mon_to_sco_mbx;

  bit [7:0] reference_mem[256] = '{default:12};

  int count = 0;
  int len   = 0;
  bit [31:0] expected_read_data;


  function new( mailbox #(ahb_transaction) mon_to_sco_mbx );
    this.mon_to_sco_mbx = mon_to_sco_mbx;
  endfunction


  task run();

    forever
      begin


      mon_to_sco_mbx.get(trans);

         if(trans.hwrite == 1'b1) begin
           $display("[SCO] : DATA WRITE");
           reference_mem[trans.haddr] = trans.hwdata[7:0];
           reference_mem[trans.haddr + 1] = trans.hwdata[15:8];
           reference_mem[trans.haddr + 2] = trans.hwdata[23:16];
           reference_mem[trans.haddr + 3] = trans.hwdata[31:24];
           end

        if(trans.hwrite == 1'b0) begin
            expected_read_data = {reference_mem[trans.haddr + 3], reference_mem[trans.haddr + 2], reference_mem[trans.haddr + 1], reference_mem[trans.haddr]};
             if(trans.hrdata == 32'h0c0c0c0c)
             $display("[SCO] : EMPTY LOCATION READ");
             else if (trans.hrdata == expected_read_data)
             $display("[SCO] : DATA MATCHED");
             else
             $display("[SCO] : DATA MISMATCHED");
         end


         ->scoreboard_next;
    end
  endtask


endclass


//////////////////////////////////////////////////////////////////////////////////////
module tb;

  ahb_monitor mon;
  ahb_generator gen;
  ahb_driver drv;
  ahb_scoreboard sco;


  event next_gen_driver;
  event next_gen_scoreboard;
  event done;

   mailbox #(ahb_transaction) gen_to_drv_mbx, mon_to_sco_mbx;
   mailbox #(bit[4:0]) gen_to_mon_len_mbx;

  ahb_if bus_if();

  ahb_slave dut (bus_if.clk, bus_if.hwdata, bus_if.haddr, bus_if.hsize, bus_if.hburst, bus_if.hresetn, bus_if.hsel, bus_if.hwrite, bus_if.htrans, bus_if.hresp, bus_if.hready, bus_if.hrdata);

  initial begin
    bus_if.clk <= 0;
  end

  always #5 bus_if.clk <= ~bus_if.clk;

  initial begin
    gen_to_drv_mbx = new();
    mon_to_sco_mbx = new();
    gen_to_mon_len_mbx = new();

    gen = new(gen_to_drv_mbx, gen_to_mon_len_mbx);
    drv = new(gen_to_drv_mbx);
    mon = new(mon_to_sco_mbx, gen_to_mon_len_mbx);
    sco = new(mon_to_sco_mbx);

    gen.count = 3;

    drv.bus_if = bus_if;
    mon.bus_if = bus_if;

    drv.driver_next = next_gen_driver;
    gen.driver_next = next_gen_driver;

    gen.scoreboard_next = next_gen_scoreboard;
    sco.scoreboard_next = next_gen_scoreboard;

  end

  initial begin
    drv.reset();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_none
    wait(gen.done.triggered);
    $finish();
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

assign bus_if.transfer_addr = dut.transfer_addr;

endmodule
