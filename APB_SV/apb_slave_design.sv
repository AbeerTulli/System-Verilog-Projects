module apb_slave(
  input pclk,
  input prstn,
  input [31:0] paddr, // the p in paddr, denotes APB
  input psel,
  input pwrite,
  input [7:0] pwdata, 
  input penable,
  
  output reg [7:0] prdata,
  output reg pready,
  output pslverr
);
  
  localparam [1:0] idle = 2'b00, write = 2'b01, read = 2'b10;
  //parameters make the code more readable. for example instead of writing : if(state == 2'b00); , you can write if(state == idle);
  
  //defining states for APB FSM
  reg [1:0] curr_state, next_state;
  
  //define memory ( what we are going to be working with)
  reg [7:0] mem[0:16]; // 16 rows holding 8 bit data each. 
  // why we have used [31:0] ? you will see in some time
  
  // defining different types of errors we can encounter
  bit addr_err, setup_err, addr_val_err, data_val_err;
  // addr_err : wrong addr, ( eg: if outside range of 16)
  // setup_err : following APB FSM or not
  // addr_val_err : should be >= 0
  // data_val_err : should be >= 0
  
  //implementing reset
  always @(posedge pclk, negedge prstn) // negedge : since asynchronous reset
    begin
      if(prstn == 1'b0) 
        curr_state <= idle;
      else 
        curr_state <= next_state; // nstate is determined by different mechanisms
    end
  
  //deciding next state
  always_comb // combinational logic, since we want next_state
    begin
      case(curr_state)
        
        idle : 
          begin
            prdata = 8'h00;
            pready = 1'b0;
            
            if(psel == 1'b1 && pwrite == 1'b1) 
              next_state = write;
            else if (psel == 1'b1 && pwrite == 1'b0)
              next_state = read;
            else 
              next_state = idle;
          end
        
        write: // here we need to update memory and are working in the 2nd cycle
          begin
            if(psel == 1'b1 && penable == 1'b1)
              begin
                if(!addr_err && !addr_val_err && !data_val_err) begin //execute if NONE of the errors are present
                  // if no errors : write data to memory
                  pready = 1'b1;
                  mem[paddr] = pwdata;
                  next_state = idle;
                end
                else 
                  begin
                    // if errors : DONT write data to memory , but still pready = 1
                    next_state = idle;
                    pready = 1'b1;
                  end
              end
          end
        read : 
            begin
              if(psel == 1'b1 && penable == 1'b1) begin
                //checking we have a valid 2nd cycle of an APB transfer
                
                if(!addr_err && !addr_val_err && !data_val_err)
                  begin
                    pready = 1'b1;
                    prdata = mem[paddr];
                    next_state = idle;
                  end
                 else
                    begin
                      pready = 1'b1;
                      prdata = 8'h00;
                      next_state = idle;
                    end
              end
            end
        default : 
              begin
                next_state = idle;
                pready = 1'b0;
                prdata = 8'h00;
              end
      endcase
    end
  
  // checking for errors:
  reg non_valid_addr_val = 0;
  always@(*) begin
    if(paddr >= 0 ) 
      non_valid_addr_val = 1'b0;
    else 
      non_valid_addr_val = 1'b1;
  end
  
//   reg non_valid_data_val = 0; 
//   always_comb begin
//     if(pwdata >= 0)
//       non_valid_data_val = 1'b0;
//     else
//       non_valid_data_val = 1'b1;
//   end
  // this wont work , cause the always_comb block needs that it is the only block driving the variables. 
  //Variables written on left-hand of "always_comb" cannot be written to by any other processes, including other "always_comb" processes.
  
  //correct method
  reg non_valid_data_val = 0; 
  always@(*) begin
    if(pwdata >= 0)
      non_valid_data_val = 1'b0;
    else
      non_valid_data_val = 1'b1;
  end
  
  assign addr_err = ((next_state == write || read ) && (paddr> 15)) ? 1'b1 : 1'b0;
    // jab meri next state, read ya write hogi. aur address for slave, range ke bahar hoga.
  assign addr_val_err = (next_state == write || read) ? non_valid_addr_val : 1'b0;
  assign data_val_err = (next_state == write || read ) ? non_valid_data_val : 1'b0;
  
  assign pslverr = (psel == 1'b1 && penable == 1'b1) ? (addr_err || addr_val_err || data_val_err) : 1'b0;
  
endmodule

interface apb_inf;
  logic pclk;
  logic prstn;
  logic [31:0] paddr; // the p in paddr, denotes APB
  logic psel;
  logic pwrite;
  logic [7:0] pwdata; 
  logic penable;
  
  logic [7:0] prdata;
  logic pready;
  logic pslverr;
  
endinterface