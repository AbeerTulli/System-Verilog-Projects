`ifndef RAM_TEST_SV
`define RAM_TEST_SV

`include "ram_env.sv"

//=================================
// ram_base_test
// it doesnt perform any specific verification function itself, instead it provides the common infrastructure that every test will need.
// each new test , inherits this infrastructure and only defines what kind of stimulus to generate.
//=================================

class ram_base_test;
  
  virtual ram_if.WRITE_DRV wr_vif;
  virtual ram_if.READ_DRV rd_vif;
  virtual ram_if.WR_MON wr_mon_vif;
  virtual ram_if.RD_MON rd_mon_vif;
  
  ram_env env;
  
  logic [6:0] empty_addrs[];
  logic [7:0] empty_datas[];
  
  function new(virtual ram_if.WRITE_DRV wr_vif,
               virtual ram_if.READ_DRV rd_vif,
               virtual ram_if.WR_MON wr_mon_vif,
               virtual ram_if.RD_MON rd_mon_vif);
    this.wr_vif = wr_vif;
    this.rd_vif = rd_vif;
    this.wr_mon_vif = wr_mon_vif;
    this.rd_mon_vif = rd_mon_vif;
    empty_addrs = new[0];
    empty_datas = new[0];
  endfunction
  
  virtual function void build_env();
    env = new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    env.build();
  endfunction
  
  virtual task body(); 
    $fatal(1, "[TEST] base body() called directly - override in child"); // prevents direct usage of ram_base_test.run()
  endtask
  
  virtual task drain(int unsigned cycles = 30);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

  task run();
    build_env();
    env.start(); // this internally does fork join
    body();// now control goes to the child, whatever test is planned executes here 
    drain();// introduces 20-30 waiting cycles,to let scoreboard finish comparisons 
  endtask
  
  task do_writes_then_reads(
    input logic [6:0] addrs [],
    input logic [7:0] datas [],
    input int unsigned n
  );
    env.run(addrs, datas, n, addrs,n,0);
  endtask
  
  task do_writes_only(
    input logic [6:0] addrs[],
    input logic [7:0] datas [],
    input int unsigned n);
    env.run(addrs,datas,n,empty_addrs,0,0);
  endtask
  
  task do_reads_only(
    input logic [6:0] addrs [],
    input int unsigned n
  );
    env.run(empty_addrs, empty_datas, 0, addrs, n, 0);
  endtask
  
  task do_writes_then_reads_diff_addr(
    input logic [6:0] wr_addrs[],
    input logic [7:0] wr_datas[],
    input int unsigned n_writes,
    input logic [6:0] rd_addrs [],
    input int unsigned n_reads);
    env.run(wr_addrs, wr_datas, n_writes, rd_addrs, n_reads, 0);
    // this  case - we use different address for read and write. unlike 
  endtask
  
endclass : ram_base_test

//====================================
// TEST - 1 (RANDOM R/W)
// Perform 32 random write transactions followed by 16 random read transactions.
//====================================
class ram_random_test extends ram_base_test;
  
  int unsigned num_writes;
  int unsigned num_reads;
  
  function new(virtual ram_if.WRITE_DRV wr_vif,
               virtual ram_if.READ_DRV rd_vif,
               virtual ram_if.WR_MON wr_mon_vif,
               virtual ram_if.RD_MON rd_mon_vif,
               int unsigned num_writes = 32,
               int unsigned num_reads = 16);
    super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif); // calling base class constructor, initializing everything
    this.num_writes = num_writes;
    this.num_reads = num_reads;
  endfunction
  
  virtual task body();
    $display("\n [TEST] ===== ram_random_test ====");
    env.run(empty_addrs, empty_datas, // not passing write addresses and data since we want generator to pass random addr.
            num_writes,
            empty_addrs, //want to randomize read addr.
            num_reads,
            1); // randomize flag 
  endtask
endclass : ram_random_test

//==================================
// BLOCK BOUNDARY TEST
// there are 128 words of 8 bit each, 128/4. 32 word block. addressed by 00 to 1F. 
// in this, we are testing the boundary cases of each block. 
//==================================

class ram_block_boundary_test extends ram_base_test;
  
  function new(virtual ram_if.WRITE_DRV wr_vif,
               virtual ram_if.READ_DRV rd_vif,
               virtual ram_if.WR_MON wr_mon_vif,
               virtual ram_if.RD_MON rd_mon_vif);
    super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
  endfunction
  
  virtual task body();
    logic [6:0] addrs[];
    logic [7:0] datas[];
    logic [6:0] rd_addrs[];
    addrs = new[8];
    datas = new[8];
    $display("\n [TEST] ==== ram_block_boundary_test ====");
    addrs[0] = 7'h00; addrs[1] = 7'h1F;
    addrs[2] = 7'h20; addrs[3] = 7'h3F;
    addrs[4] = 7'h40; addrs[5] = 7'h5F;
    addrs[6] = 7'h60; addrs[7] = 7'h7F;
    
    datas[0] = 8'hAA; datas[1] = 8'hBB;
    datas[2] = 8'hCC; datas[3] = 8'hDD;
    datas[4] = 8'hEE; datas[5] = 8'hFF;
    datas[6] = 8'h11; datas[7] = 8'h22;
    
    rd_addrs[0] = 7'h00; rd_addrs[1] = 7'h1F;
    rd_addrs[2] = 7'h20; rd_addrs[3] = 7'h3F;
    rd_addrs[4] = 7'h40; rd_addrs[5] = 7'h5F;
    rd_addrs[6] = 7'h60; rd_addrs[7] = 7'h7F;
    
    do_writes_then_reads_diff_addr(addrs, datas, 8, rd_addrs, 8);
  endtask
  
endclass: ram_block_boundary_test

// ===================================================================
// TEST 3 - Full Address Sweep
// ===================================================================
class ram_full_sweep_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 400);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;
        addrs    = new[128];
        datas    = new[128];
        rd_addrs = new[128];
        $display("\n[TEST] ===== ram_full_sweep_test =====");
        for (i = 0; i < 128; i++) begin
            addrs[i]    = i[6:0];
            datas[i]    = ~i[7:0];
            rd_addrs[i] = i[6:0];
        end
        do_writes_then_reads_diff_addr(addrs, datas, 128, rd_addrs, 128);
    endtask

endclass : ram_full_sweep_test

// ===================================================================
// TEST 4 - Walking 1s on Data Bus
// ===================================================================
class ram_walking1_data_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;
        addrs    = new[8];
        datas    = new[8];
        rd_addrs = new[8];
        $display("\n[TEST] ===== ram_walking1_data_test =====");
        for (i = 0; i < 8; i++) begin
            addrs[i]    = i[6:0];
            datas[i]    = 8'h01 << i;
            rd_addrs[i] = i[6:0];
        end
        do_writes_then_reads_diff_addr(addrs, datas, 8, rd_addrs, 8);
    endtask

endclass : ram_walking1_data_test

// ===================================================================
// TEST 5 - Walking 0s on Data Bus
// ===================================================================
class ram_walking0_data_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;
        addrs    = new[8];
        datas    = new[8];
        rd_addrs = new[8];
        $display("\n[TEST] ===== ram_walking0_data_test =====");
        for (i = 0; i < 8; i++) begin
            addrs[i]    = i[6:0];
            datas[i]    = ~(8'h01 << i);
            rd_addrs[i] = i[6:0];
        end
        do_writes_then_reads_diff_addr(addrs, datas, 8, rd_addrs, 8);
    endtask

endclass : ram_walking0_data_test

// ===================================================================
// TEST 6 - Walking 1s on Address Bus
// ===================================================================
class ram_walking1_addr_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;
        addrs    = new[7];
        datas    = new[7];
        rd_addrs = new[7];
        $display("\n[TEST] ===== ram_walking1_addr_test =====");
        for (i = 0; i < 7; i++) begin
            addrs[i]    = 7'h01 << i;
            datas[i]    = 8'hA0 | i[7:0];
            rd_addrs[i] = 7'h01 << i;
        end
        do_writes_then_reads_diff_addr(addrs, datas, 7, rd_addrs, 7);
    endtask

endclass : ram_walking1_addr_test

// ===================================================================
// TEST 7 - Walking 0s on Address Bus
// ===================================================================
class ram_walking0_addr_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;
        addrs    = new[7];
        datas    = new[7];
        rd_addrs = new[7];
        $display("\n[TEST] ===== ram_walking0_addr_test =====");
        for (i = 0; i < 7; i++) begin
            addrs[i]    = ~(7'h01 << i);
            datas[i]    = 8'hB0 | i[7:0];
            rd_addrs[i] = ~(7'h01 << i);
        end
        do_writes_then_reads_diff_addr(addrs, datas, 7, rd_addrs, 7);
    endtask

endclass : ram_walking0_addr_test

// ===================================================================
// TEST 8 - Same-Address Back-to-Back Overwrite
// ===================================================================
class ram_same_addr_overwrite_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 100);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] victims[];
        logic [7:0] first_data[];
        logic [7:0] second_data[];
        logic [6:0] a[];
        logic [6:0] ra[];
        logic [7:0] d1[];
        logic [7:0] d2[];
        int i;

        victims     = new[8];
        first_data  = new[8];
        second_data = new[8];
        a           = new[1];
        ra          = new[1];
        d1          = new[1];
        d2          = new[1];

        $display("\n[TEST] ===== ram_same_addr_overwrite_test =====");
      victims[0] = 7'h00; // first address
      victims[1] = 7'h10; // aligned/block memory
      victims[2] = 7'h1F; // end of block
      victims[3] = 7'h20; // next block start
      victims[4] = 7'h3F; // another boundary
      victims[5] = 7'h55; // alternating bit patern 0101 0101
      victims[6] = 7'h70; // upper region
      victims[7] = 7'h7F; // last address

      first_data[0] = 8'hAA; // alternating 1010
      first_data[1] = 8'h55; // alternating 0101
      first_data[2] = 8'hFF; // all 1s
      first_data[3] = 8'h00; // all 0s
      first_data[4] = 8'h0F; //lower nibble
      first_data[5] = 8'hF0; //upper nibble
      first_data[6] = 8'hA5; // mixed
      first_data[7] = 8'h5A; // mixed inverse

      second_data[0] = 8'h55; second_data[1] = 8'hAA; // flipping the data of 0 and 1 
      second_data[2] = 8'h00; second_data[3] = 8'hFF; // flipping the data of 2 and 3
      second_data[4] = 8'hF0; second_data[5] = 8'h0F; // flipping the data of 4 and 5
      second_data[6] = 8'h5A; second_data[7] = 8'hA5; //flipping the data of 6 and 7

        for (i = 0; i < 8; i++) begin
            a[0]  = victims[i];
            ra[0] = victims[i];
            d1[0] = first_data[i];
            d2[0] = second_data[i];

            do_writes_only(a, d1, 1);
            do_writes_only(a, d2, 1);
          do_reads_only(ra, 1); // checking if the data given is being overriden or not
        end
    endtask

endclass : ram_same_addr_overwrite_test
  
// ===================================================================
// TEST 9 - Toggle (Write-Read-Write-Read) Same Address
// ===================================================================
class ram_toggle_addr_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 80);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] addrs[];
        logic [6:0] a[];
        logic [6:0] ra[];
        logic [7:0] d1[];
        logic [7:0] d2[];
        int i;
        addrs = new[4];
        a     = new[1];
        ra    = new[1];
        d1    = new[1];
        d2    = new[1];

        $display("\n[TEST] ===== ram_toggle_addr_test =====");

        addrs[0] = 7'h00; addrs[1] = 7'h2A;
        addrs[2] = 7'h55; addrs[3] = 7'h7F;

        d1[0] = 8'hC3;
        d2[0] = 8'h3C;

        for (i = 0; i < 4; i++) begin
            a[0]  = addrs[i];
            ra[0] = addrs[i];

            do_writes_only(a, d1, 1);
            do_reads_only (ra, 1);
            do_writes_only(a, d2, 1);
            do_reads_only (ra, 1);
        end
    endtask

endclass : ram_toggle_addr_test

// ===================================================================
// TEST 10 - Checkerboard Pattern
// ===================================================================
class ram_checkerboard_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 600);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;

        addrs    = new[128];
        datas    = new[128];
        rd_addrs = new[128];

        $display("\n[TEST] ===== ram_checkerboard_test =====");

        for (i = 0; i < 128; i++) begin
            addrs[i]    = i[6:0];
            rd_addrs[i] = i[6:0];
        end

        // Pass 1: 0xAA/0x55
        for (i = 0; i < 128; i++)
            datas[i] = (i % 2 == 0) ? 8'hAA : 8'h55;

        do_writes_then_reads_diff_addr(addrs, datas, 128, rd_addrs, 128);

        // Pass 2: inverted
        for (i = 0; i < 128; i++)
            datas[i] = (i % 2 == 0) ? 8'h55 : 8'hAA;

        do_writes_then_reads_diff_addr(addrs, datas, 128, rd_addrs, 128);
    endtask

endclass : ram_checkerboard_test

// ===================================================================
// TEST 11 - Block Isolation
// ===================================================================
class ram_block_isolation_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 600);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] blk0_addrs[];
        logic [7:0] blk0_datas[];
        logic [6:0] blk123_addrs[];
        logic [7:0] blk123_datas[];
        logic [6:0] rd_addrs[];
        int i;
        int tmp;

        blk0_addrs   = new[32];
        blk0_datas   = new[32];
        blk123_addrs = new[96];
        blk123_datas = new[96];
        rd_addrs     = new[32];

        $display("\n[TEST] ===== ram_block_isolation_test =====");

        for (i = 0; i < 32; i++) begin
            blk0_addrs[i] = i[6:0];
            blk0_datas[i] = 8'hDE;
            rd_addrs[i]   = i[6:0];
        end

        for (i = 0; i < 96; i++) begin
            tmp             = i + 32;
            blk123_addrs[i] = tmp[6:0];
            blk123_datas[i] = i[0] ? 8'hFF : 8'h00;
        end

        do_writes_only(blk0_addrs,   blk0_datas,   32);
        do_writes_only(blk123_addrs, blk123_datas, 96);
        do_reads_only (rd_addrs,     32);

    endtask

endclass : ram_block_isolation_test

// ===================================================================
// TEST 12 - All-Zeros Data
// ===================================================================
class ram_allzero_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 400);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;

        addrs    = new[128];
        datas    = new[128];
        rd_addrs = new[128];

        $display("\n[TEST] ===== ram_allzero_test =====");

        for (i = 0; i < 128; i++) begin
            addrs[i]    = i[6:0];
            datas[i]    = 8'h00;
            rd_addrs[i] = i[6:0];
        end

        do_writes_then_reads_diff_addr(addrs, datas, 128, rd_addrs, 128);
    endtask

endclass : ram_allzero_test

// ===================================================================
// TEST 13 - All-Ones Data
// ===================================================================
class ram_allone_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 400);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] addrs[];
        logic [7:0] datas[];
        logic [6:0] rd_addrs[];
        int i;

        addrs    = new[128];
        datas    = new[128];
        rd_addrs = new[128];

        $display("\n[TEST] ===== ram_allone_test =====");

        for (i = 0; i < 128; i++) begin
            addrs[i]    = i[6:0];
            datas[i]    = 8'hFF;
            rd_addrs[i] = i[6:0];
        end

        do_writes_then_reads_diff_addr(addrs, datas, 128, rd_addrs, 128);
    endtask

endclass : ram_allone_test

// ===================================================================
// TEST 14 - Read Before Write (reads to untouched memory must
// return the DUT's known power-on/reset value: 0x00 in this model)
// ===================================================================
class ram_read_before_write_test extends ram_base_test;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
    endfunction

    virtual task drain(int unsigned cycles = 100);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] rd_addrs[];
        logic [6:0] wr_addrs[];
        logic [7:0] wr_datas[];
        int i;

        rd_addrs = new[16];
        wr_addrs = new[16];
        wr_datas = new[16];

        $display("\n[TEST] ===== ram_read_before_write_test =====");

        // Phase 1: read untouched locations first - reference model
        // also starts at all-zero, so this exercises the "no write
        // yet observed" path on both DUT and scoreboard.
        for (i = 0; i < 16; i++)
            rd_addrs[i] = (i * 8) & 7'h7F;

        do_reads_only(rd_addrs, 16);

        // Phase 2: now write the same locations and read them back.
        for (i = 0; i < 16; i++) begin
            wr_addrs[i] = rd_addrs[i];
            wr_datas[i] = 8'hC0 | i[7:0];
        end

        do_writes_then_reads_diff_addr(wr_addrs, wr_datas, 16, rd_addrs, 16);
    endtask

endclass : ram_read_before_write_test

// ===================================================================
// TEST 15 - Constrained Weighted Random
// ===================================================================
class ram_constrained_weighted_test extends ram_base_test;

    int unsigned num_writes;
    int unsigned num_reads;

    function new(virtual ram_if.WRITE_DRV wr_vif,
                 virtual ram_if.READ_DRV  rd_vif,
                 virtual ram_if.WR_MON    wr_mon_vif,
                 virtual ram_if.RD_MON    rd_mon_vif,
                 int unsigned num_writes = 64,
                 int unsigned num_reads  = 64);
        super.new(wr_vif, rd_vif, wr_mon_vif, rd_mon_vif);
        this.num_writes = num_writes;
        this.num_reads  = num_reads;
    endfunction

    virtual task drain(int unsigned cycles = 400);
        repeat (cycles) @(env.wr_vif.wr_cb);
        env.report();
    endtask

    virtual task body();
        logic [6:0] wr_addrs[];
        logic [7:0] wr_datas[];
        logic [6:0] rd_addrs[];
        int i;

        // Weighted toward block 0 (addr[6:5]==0) to stress one
        // decoder leg, mixed with a few addresses from other blocks.
        wr_addrs = new[num_writes];
        wr_datas = new[num_writes];
        rd_addrs = new[num_reads];

        $display("\n[TEST] ===== ram_constrained_weighted_test =====");

        for (int unsigned i = 0; i < num_writes; i++) begin
            if ((i % 4) != 0)
                wr_addrs[i] = $urandom_range(0, 31);         // block 0 - 75%
            else
                wr_addrs[i] = $urandom_range(32, 127);       // blocks 1-3 - 25%

            wr_datas[i] = $urandom_range(0, 255);
        end

        for (i = 0; i < num_reads; i++) begin
            if ((i % 4) != 0)
                rd_addrs[i] = $urandom_range(0, 31);
            else
                rd_addrs[i] = $urandom_range(32, 127);
        end

        do_writes_then_reads_diff_addr(wr_addrs, wr_datas, num_writes, rd_addrs, num_reads);
    endtask

endclass : ram_constrained_weighted_test

`endif
