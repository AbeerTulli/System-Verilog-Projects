
module AXI_LITE_S(
  input wire axi_aclk,
  input wire axi_aresetn,

  input wire axi_awvalid,
  output reg axi_awready,
  input wire [31:0] axi_awaddr,

  input wire axi_wvalid,
  output reg axi_wready,
  input wire [31:0] axi_wdata,

  output reg axi_bvalid,
  input wire axi_bready,
  output reg [1:0] axi_bresp,

  input wire axi_arvalid,
  output reg axi_arready,
  input wire [31:0] axi_araddr,

  output reg axi_rvalid,
  input wire axi_rready,
  output reg [31:0] axi_rdata,
  output reg [1:0] axi_rresp
);

  localparam idle = 0,
             send_waddr_ack = 1,
             send_raddr_ack = 2,
             send_wdata_ack = 3,
             update_mem = 4,
             send_wr_err = 5,
             send_wr_resp = 6,
             gen_data = 7,
             send_rd_err = 8,
             send_rdata = 9;

  reg [3:0] state = idle;
  reg [3:0] next_state = idle;
  reg [1:0] count = 0;

  reg [31:0] waddr, raddr, wdata, rdata;
  reg [31:0] mem [0:127];

  always @(posedge axi_aclk)
  begin
    if(axi_aresetn == 1'b0)
    begin
      state <= idle;

      for(int i = 0; i < 128; i++)
        mem[i] <= 0;

      axi_awready <= 0;
      axi_wready <= 0;
      axi_bvalid <= 0;
      axi_bresp <= 0;

      axi_arready <= 0;
      axi_rvalid <= 0;
      axi_rdata <= 0;
      axi_rresp <= 0;

      waddr <= 0;
      raddr <= 0;
      wdata <= 0;
      rdata <= 0;
    end

    else
    begin
      case(state)

        idle:
        begin
          axi_awready <= 0;
          axi_wready <= 0;
          axi_bvalid <= 0;
          axi_bresp <= 0;

          axi_arready <= 0;
          axi_rvalid <= 0;
          axi_rdata <= 0;
          axi_rresp <= 0;

          waddr <= 0;
          raddr <= 0;
          wdata <= 0;
          rdata <= 0;
          count <= 0;

          axi_rvalid <= 1'b0;

          if(axi_awvalid == 1'b1)
          begin
            state <= send_waddr_ack;
            waddr <= axi_awaddr;
            axi_awready <= 1'b1;
          end

          else if(axi_arvalid == 1'b1)
          begin
            state <= send_raddr_ack;
            raddr <= axi_araddr;
            axi_arready <= 1'b1;
          end

          else
          begin
            state <= idle;
          end
        end

        send_waddr_ack:
        begin
          axi_awready <= 1'b0;

          if(axi_wvalid)
          begin
            wdata <= axi_wdata;
            axi_wready <= 1'b1;
            state <= send_wdata_ack;
          end

          else
          begin
            state <= send_waddr_ack;
          end
        end

        send_wdata_ack:
        begin
          axi_wready <= 1'b0;

          if(waddr < 128)
          begin
            state <= update_mem;
            mem[waddr] <= wdata;
          end

          else
          begin
            state <= send_wr_err;
            axi_bresp <= 2'b11;
            axi_bvalid <= 1'b1;
          end
        end

        update_mem:
        begin
          mem[waddr] <= wdata;
          state <= send_wr_resp;
        end

        send_wr_resp:
        begin
          axi_bresp <= 2'b00;
          axi_bvalid <= 1'b1;

          if(axi_bready)
            state <= idle;
          else
            state <= send_wr_resp;
        end

        send_wr_err:
        begin
          if(axi_bready)
            state <= idle;
          else
            state <= send_wr_err;
        end

        // Read operation

        send_raddr_ack:
        begin
          axi_arready = 1'b0;

          if(raddr < 128)
            state <= gen_data;

          else
          begin
            axi_rvalid <= 1'b1;
            state <= send_rd_err;
            axi_rdata <= 0;
            axi_rresp <= 2'b11;
          end
        end

        gen_data:
        begin
          if(count < 2)
          begin
            rdata <= mem[raddr];
            state <= gen_data;
            count <= count + 1;
          end

          else
          begin
            axi_rvalid <= 1'b1;
            axi_rdata <= rdata;
            axi_rresp <= 2'b00;

            if(axi_rready)
              state <= idle;
            else
              state <= gen_data;
          end
        end

        send_rd_err:
        begin
          if(axi_rready)
            state <= idle;
          else
            state <= send_rd_err;
        end

        default:
          state <= idle;

      endcase
    end
  end

endmodule


//////////////////////////////////
// AXI interface

interface axi_if;

  logic clk, resetn;

  logic awvalid, awready;
  logic arvalid, arready;
  logic wvalid, wready;
  logic bready, bvalid;
  logic rvalid, rready;

  logic [31:0] awaddr, araddr, wdata, rdata;
  logic [1:0] wresp, rresp;

endinterface
