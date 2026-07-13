`timescale 1ns/1ps

`include "ram_test.sv"
`include "decoder_ram.sv"

module ram_tb_top;

  //========================================
  // Clock
  //========================================
  logic clk;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //========================================
  // Interface
  //========================================
  ram_if ramif(clk);

  //========================================
  // DUT
  //========================================
  decoder_ram dut (
    .clk   (clk),
    .rst_n (ramif.rst_n),

    .we    (ramif.we),
    .re    (ramif.re),

    .addr  (ramif.addr),

    .wdata (ramif.wdata),
    .rdata (ramif.rdata),

    .valid (ramif.valid)
  );

  //========================================
  // Test Variables
  //========================================
  string testname;
  ram_base_test test;

  //========================================
  // Test Selection & Execution
  //========================================
  initial begin

    // Get test name from command line
    if (!$value$plusargs("TESTNAME=%s", testname)) begin
      $display("\n==============================");
      $display("[TOP] ERROR : TESTNAME NOT PROVIDED");
      $display("==============================");
      $display("Usage:");
      $display("vsim work.ram_tb_top +TESTNAME=ram_random_test");
      $finish;
    end

    // Display selected test
    $display("\n==============================");
    $display("[TOP] RUNNING TEST : %s", testname);
    $display("==============================\n");

    // Create Test
    case (testname)

      "ram_random_test":
        test = ram_random_test:: new( // :: is used to access contents of a class without creating an object
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_block_boundary_test":
        test = ram_block_boundary_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_full_sweep_test":
        test = ram_full_sweep_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_walking1_data_test":
        test = ram_walking1_data_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_walking0_data_test":
        test = ram_walking0_data_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_walking1_addr_test":
        test = ram_walking1_addr_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_walking0_addr_test":
        test = ram_walking0_addr_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_same_addr_overwrite_test":
        test = ram_same_addr_overwrite_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_toggle_addr_test":
        test = ram_toggle_addr_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_checkerboard_test":
        test = ram_checkerboard_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_block_isolation_test":
        test = ram_block_isolation_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_allzero_test":
        test = ram_allzero_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_allone_test":
        test = ram_allone_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_read_before_write_test":
        test = ram_read_before_write_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      "ram_constrained_weighted_test":
        test = ram_constrained_weighted_test :: new(
          ramif,
          ramif,
          ramif,
          ramif
        );

      default: begin
        $display("\n==============================");
        $display("[TOP] ERROR : UNKNOWN TEST");
        $display("[TOP] TESTNAME = %s", testname);
        $display("==============================");
        $finish;
      end

    endcase

    // Run Test
    test.run();

    // Finish
    $display("\n==============================");
    $display("[TOP] TEST COMPLETED : %s", testname);
    $display("==============================");

    #20;

    $display("[TOP] All tests completed.");

    $finish;

  end

endmodule
