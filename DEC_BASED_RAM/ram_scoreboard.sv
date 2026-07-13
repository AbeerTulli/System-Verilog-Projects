//ram_scoreboard.sv

//compares actual reads results (from ram_read_monitor)[NOT directly from DUT] against expected results from ram_ref_model

`ifndef RAM_SCOREBOARD_SV
`define RAM_SCOREBOARD_SV

`include "ram_transaction.sv"
`include "ram_if.sv"

class ram_scoreboard;
  
  mailbox #(ram_transaction) sb_rd_mbx;
  mailbox #(ram_transaction) sb_exp_mbx;
  mailbox #(ram_transaction) sb_wr_mbx;
  
  int unsigned pass_count;
  int unsigned fail_count;
  int unsigned write_count;
  
  function new(mailbox #(ram_transaction) sb_rd_mbx,
               mailbox #(ram_transaction) sb_exp_mbx,
               mailbox #(ram_transaction) sb_wr_mbx);
    
    this.sb_rd_mbx = sb_rd_mbx;
    this.sb_exp_mbx = sb_exp_mbx;
    this.sb_wr_mbx = sb_wr_mbx;
    
  endfunction
  
  task run_check(); //checks transactions
    
    ram_transaction actual, expected;
    
    $display("sb started");
    
    forever begin
      sb_rd_mbx.get(actual); //getting via the read monitor via mailbox 
      sb_exp_mbx.get(expected); // getting from ref_model via mailbox 
      
      check(actual,expected);
    end
  endtask
  
  function void check(ram_transaction actual, 
                 ram_transaction expected);
    
    bit addr_match;
    bit data_match;
    bit valid_match;
    
    addr_match = (actual.addr == expected.addr);
    data_match = (actual.rdata == expected.rdata);
    valid_match = (actual.valid == expected.valid);
    
    if(addr_match && data_match && valid_match)
      begin
      pass_count++;
    $display("sb passed addr = %0d, data = %0d", actual.addr, actual.rdata);
      end
    
    else
      begin
        fail_count++;
        if(!addr_match)
          $display("address mismatch");
        
        else if (!data_match)
          $display("data mismatch");
        else 
          $display("valid mismatch");
        
      end
  endfunction
  
    function void report();

        $display("\n========================================================");
        $display("[SB] SCOREBOARD REPORT");
        $display("[SB]   Writes observed : %0d", write_count);
        $display("[SB]   Reads passed    : %0d", pass_count);
        $display("[SB]   Reads failed    : %0d", fail_count);

        if (fail_count == 0)
            $display("[SB]   RESULT          : PASS");
        else
            $display("[SB]   RESULT          : FAIL");

        $display("========================================================\n");

    endfunction
  
endclass
`endif
