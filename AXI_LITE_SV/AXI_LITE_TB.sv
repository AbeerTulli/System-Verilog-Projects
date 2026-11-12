
class axi_transaction;

  randc bit op;
  rand bit [31:0] write_addr;
  rand bit [31:0] write_data;
  rand bit [31:0] read_addr;
  bit [31:0] read_data;
  bit [1:0] write_resp;
  bit [1:0] read_resp;

  constraint valid_addr_range {write_addr == 1; read_addr == 1;}
  constraint valid_data_range {write_data < 12; read_data < 12;}

endclass


//////////////////////////////////

class axi_generator;

  axi_transaction tr;
  mailbox #(axi_transaction) mbx_gen_drv;

  event done;
  event score_next;

  int count = 0;

  function new(mailbox #(axi_transaction) mbx_gen_drv);
    this.mbx_gen_drv = mbx_gen_drv;
    tr = new();
  endfunction

  task run();
    for(int i = 0; i < count; i++)
    begin
      assert(tr.randomize()) else $error("Randomization Failed");
      $display("[GEN] OP: %0b write_addr: %0d write_data: %0d read_addr: %0d",
               tr.op, tr.write_addr, tr.write_data, tr.read_addr);
      mbx_gen_drv.put(tr);
      @(score_next);
    end
    ->done;
  endtask

endclass


//////////////////////////////////

class axi_driver;

  virtual axi_if vif;
  axi_transaction tr;

  mailbox #(axi_transaction) mbx_gen_drv;
  mailbox #(axi_transaction) mbx_drv_mon;

  function new(mailbox #(axi_transaction) mbx_gen_drv, mailbox #(axi_transaction) mbx_drv_mon);
    this.mbx_gen_drv = mbx_gen_drv;
    this.mbx_drv_mon = mbx_drv_mon;
  endfunction

  // Resetting system
  task reset();

    vif.axi_aresetn <= 1'b0;
    vif.axi_awvalid <= 1'b0;
    vif.axi_awaddr <= 0;
    vif.axi_wvalid <= 0;
    vif.axi_wdata <= 0;
    vif.axi_bready <= 0;
    vif.axi_arvalid <= 1'b0;
    vif.axi_araddr <= 0;
    vif.axi_rready <= 0;

    repeat(5) @(posedge vif.axi_aclk);
    vif.axi_aresetn <= 1'b1;

    $display("-----------------[DRV] : RESET DONE-----------------------------");

  endtask

  // Write operation
  task write_data(input axi_transaction tr);

    $display("[DRV] OP: %0b write_addr: %0d write_data: %0d",
             tr.op, tr.write_addr, tr.write_data);

    mbx_drv_mon.put(tr);

    vif.axi_aresetn <= 1'b1;
    vif.axi_awvalid <= 1'b1;
    vif.axi_arvalid <= 1'b0;
    vif.axi_araddr <= 0;
    vif.axi_awaddr <= tr.write_addr;

    @(negedge vif.axi_awready);

    vif.axi_awvalid <= 1'b0;
    vif.axi_awaddr <= 0;
    vif.axi_wvalid <= 1'b1;
    vif.axi_wdata <= tr.write_data;

    @(negedge vif.axi_wready);

    vif.axi_wvalid <= 1'b0;
    vif.axi_wdata <= 0;
    vif.axi_bready <= 1'b1;
    vif.axi_rready <= 1'b0;

    @(negedge vif.axi_bvalid);

    vif.axi_bready <= 1'b0;

  endtask

  // Read operation
  task read_data(input axi_transaction tr);

    $display("[DRV] OP: %0b read_addr: %0d", tr.op, tr.read_addr);

    mbx_drv_mon.put(tr);

    vif.axi_aresetn <= 1'b1;
    vif.axi_awvalid <= 1'b0;
    vif.axi_awaddr <= 0;
    vif.axi_wvalid <= 1'b0;
    vif.axi_wdata <= 0;
    vif.axi_bready <= 1'b0;
    vif.axi_arvalid <= 1'b1;
    vif.axi_araddr <= tr.read_addr;

    @(negedge vif.axi_arready);

    vif.axi_araddr <= 0;
    vif.axi_arvalid <= 1'b0;
    vif.axi_rready <= 1'b1;

    @(negedge vif.axi_rvalid);

    vif.axi_rready <= 1'b0;

  endtask

  task run();

    forever
    begin
      mbx_gen_drv.get(tr);
      @(posedge vif.axi_aclk);

      if(tr.op == 1'b1)
        write_data(tr);
      else
        read_data(tr);
    end

  endtask

endclass


//////////////////////////////////

class axi_monitor;

  virtual axi_if vif;
  axi_transaction tr, trd;

  mailbox #(axi_transaction) mbx_mon_sco;
  mailbox #(axi_transaction) mbx_drv_mon;

  function new(mailbox #(axi_transaction) mbx_mon_sco, mailbox #(axi_transaction) mbx_drv_mon);
    this.mbx_mon_sco = mbx_mon_sco;
    this.mbx_drv_mon = mbx_drv_mon;
  endfunction

  task run();

    tr = new();

    forever
    begin
      @(posedge vif.axi_aclk);
      mbx_drv_mon.get(trd);

      if(trd.op == 1)
      begin
        tr.op = trd.op;
        tr.write_addr = trd.write_addr;
        tr.write_data = trd.write_data;

        @(posedge vif.axi_bvalid);
        tr.write_resp = vif.axi_bresp;
        @(negedge vif.axi_bvalid);

        $display("[MON] OP: %0b write_addr: %0d write_data: %0d write_resp: %0d",
                 tr.op, tr.write_addr, tr.write_data, tr.write_resp);

        mbx_mon_sco.put(tr);
      end
      else
      begin
        tr.op = trd.op;
        tr.read_addr = trd.read_addr;

        @(posedge vif.axi_rvalid);
        tr.read_data = vif.axi_rdata;
        tr.read_resp = vif.axi_rresp;
        @(negedge vif.axi_rvalid);

        $display("[MON] OP: %0b read_addr: %0d read_data: %0d read_resp: %0d",
                 tr.op, tr.read_addr, tr.read_data, tr.read_resp);

        mbx_mon_sco.put(tr);
      end
    end

  endtask

endclass


//////////////////////////////////

class axi_scoreboard;

  axi_transaction tr;
  event score_next;

  mailbox #(axi_transaction) mbx_mon_sco;

  bit [31:0] expected_data;
  bit [31:0] reference_mem[128] = '{default:0};

  function new(mailbox #(axi_transaction) mbx_mon_sco);
    this.mbx_mon_sco = mbx_mon_sco;
  endfunction

  task run();

    forever
    begin
      mbx_mon_sco.get(tr);

      if(tr.op == 1)
      begin
        $display("[SCO] OP: %0b write_addr: %0d write_data: %0d write_resp: %0d",
                 tr.op, tr.write_addr, tr.write_data, tr.write_resp);

        if(tr.write_resp == 3)
          $display("[SCO] DEC ERROR");
        else
        begin
          reference_mem[tr.write_addr] = tr.write_data;
          $display("[SCO] DATA STORED ADDR: %0d AND DATA: %0d",
                   tr.write_addr, tr.write_data);
        end
      end
      else
      begin
        $display("[SCO] OP: %0b read_addr: %0d read_data: %0d read_resp: %0d",
                 tr.op, tr.read_addr, tr.read_data, tr.read_resp);

        expected_data = reference_mem[tr.read_addr];

        if(tr.read_resp == 3)
          $display("[SCO] DEC ERROR");
        else if(tr.read_resp == 0 && tr.read_data == expected_data)
          $display("[SCO] DATA MATCHED");
        else
          $display("[SCO] DATA MISMATCHED");
      end

      $display("----------------------------------------------------");
      ->score_next;
    end

  endtask

endclass


//////////////////////////////////

interface axi_if;

  logic axi_aclk, axi_aresetn;

  logic axi_awvalid, axi_awready;
  logic [31:0] axi_awaddr;

  logic axi_wvalid, axi_wready;
  logic [31:0] axi_wdata;

  logic axi_bready, axi_bvalid;
  logic [1:0] axi_bresp;

  logic axi_arvalid, axi_arready;
  logic [31:0] axi_araddr;

  logic axi_rvalid, axi_rready;
  logic [31:0] axi_rdata;
  logic [1:0] axi_rresp;

endinterface


//////////////////////////////////

module tb;

  axi_monitor mon;
  axi_generator gen;
  axi_driver drv;
  axi_scoreboard sco;

  event next_gd;
  event next_gm;

  mailbox #(axi_transaction) mbx_gen_drv, mbx_mon_sco, mbx_drv_mon;

  axi_if vif();

  AXI_LITE_S dut (
    .axi_aclk(vif.axi_aclk),
    .axi_aresetn(vif.axi_aresetn),
    .axi_awvalid(vif.axi_awvalid),
    .axi_awaddr(vif.axi_awaddr),
    .axi_awready(vif.axi_awready),
    .axi_wvalid(vif.axi_wvalid),
    .axi_wdata(vif.axi_wdata),
    .axi_wready(vif.axi_wready),
    .axi_bready(vif.axi_bready),
    .axi_bvalid(vif.axi_bvalid),
    .axi_bresp(vif.axi_bresp),
    .axi_arvalid(vif.axi_arvalid),
    .axi_araddr(vif.axi_araddr),
    .axi_arready(vif.axi_arready),
    .axi_rready(vif.axi_rready),
    .axi_rvalid(vif.axi_rvalid),
    .axi_rdata(vif.axi_rdata),
    .axi_rresp(vif.axi_rresp)
  );

  initial
    vif.axi_aclk = 0;

  always #5 vif.axi_aclk = ~vif.axi_aclk;

  initial
  begin
    mbx_gen_drv = new();
    mbx_mon_sco = new();
    mbx_drv_mon = new();

    gen = new(mbx_gen_drv);
    drv = new(mbx_gen_drv, mbx_drv_mon);
    mon = new(mbx_mon_sco, mbx_drv_mon);
    sco = new(mbx_mon_sco);

    gen.count = 10;

    drv.vif = vif;
    mon.vif = vif;

    gen.score_next = next_gm;
    sco.score_next = next_gm;
  end

  initial
  begin
    drv.reset();

    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any

    wait(gen.done.triggered);
    $finish;
  end

  initial
  begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

endmodule
