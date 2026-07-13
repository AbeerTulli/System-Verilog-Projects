//ram_env.sv
// this wires all TB components togrther.
// the env never builds or inspects transaction itself.

`ifndef RAM_ENV_SV
`define RAM_ENV_SV

`include "ram_transaction.sv"
`include "ram_generator.sv"
`include "ram_write_driver.sv"
`include "ram_read_driver.sv"
`include "ram_write_monitor.sv"
`include "ram_read_monitor.sv"
`include "ram_ref_model.sv"
`include "ram_scoreboard.sv"

class ram_env;
  
  ram_generator     gen;
  ram_write_driver  wr_drv;
  ram_read_driver   rd_drv;
  ram_write_monitor wr_mon;
  ram_read_monitor  rd_mon;
  ram_ref_model     rm;
  ram_scoreboard    sb;
  
  local mailbox #(ram_transaction) wr_mbx;
  local mailbox #(ram_transaction) rd_mbx;
  local mailbox #(bit)             wr_done_mbx;
  local mailbox #(ram_transaction) rd_done_mbx;
  local mailbox #(ram_transaction) rm_wr_mbx;
  local mailbox #(ram_transaction) rm_rd_mbx;
  local mailbox #(ram_transaction) sb_wr_mbx;
  local mailbox #(ram_transaction) sb_rd_mbx;
  local mailbox #(ram_transaction) sb_exp_mbx;
  
  virtual ram_if.WRITE_DRV wr_vif;
  virtual ram_if.READ_DRV  rd_vif;
  virtual ram_if.WR_MON    wr_mon_vif;
  virtual ram_if.RD_MON    rd_mon_vif;
  
  //constructor 
  function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);

        this.wr_vif     = wr_vif;
        this.rd_vif     = rd_vif;
        this.wr_mon_vif = wr_mon_vif;
        this.rd_mon_vif = rd_mon_vif;

        wr_mbx      = new();
        rd_mbx      = new();
        wr_done_mbx = new();
        rd_done_mbx = new();
        rm_wr_mbx   = new();
        rm_rd_mbx   = new();
        sb_wr_mbx   = new();
        sb_rd_mbx   = new();
        sb_exp_mbx  = new();

    endfunction
  
  function void build();

        gen    = new(wr_mbx, rd_mbx, wr_done_mbx);
        wr_drv = new(wr_vif, wr_mbx, wr_done_mbx);
        rd_drv = new(rd_vif, rd_mbx, rd_done_mbx);
        wr_mon = new(wr_mon_vif, sb_wr_mbx, rm_wr_mbx);
        rd_mon = new(rd_mon_vif, sb_rd_mbx, rm_rd_mbx);
        rm     = new(rm_wr_mbx, rm_rd_mbx, sb_exp_mbx);
        sb     = new(sb_rd_mbx, sb_exp_mbx, sb_wr_mbx);

        $display("[ENV] All components built");

    endfunction
  
  task start();

        fork
            wr_drv.run();
            rd_drv.run();
            wr_mon.run();
            rd_mon.run();
            rm.run_writes();
            rm.run_reads();
            sb.run_check();
        join_none

        wr_drv.reset(4);

        $display("[ENV] All threads started, DUT reset done");

    endtask
  
  task run(
        input logic [6:0] wr_addrs [],
        input logic [7:0] wr_datas [],
        input int unsigned n_writes,
        input logic [6:0] rd_addrs [],
        input int unsigned n_reads,
        input bit          randomize_txns = 0
    );

        gen.run(wr_addrs, wr_datas, n_writes,
                rd_addrs, n_reads,
                randomize_txns);

    endtask
  
  function void report();
        sb.report();
    endfunction

endclass : ram_env

`endif
