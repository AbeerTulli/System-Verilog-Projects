// This is the code for 128 X 8 RAM. 
// 4 blocks with one hot encoding has been used, each block with 32 rows of 8bit data. 
// to choose the block we use the last two bits of the 7 bit input 
// to choose within the block , we use the first 5 bits as word_address. 

module decoder_ram (input clk, rst_n, we,re,input [6:0] addr, input [7:0] wdata,output reg [7:0] rdata, output reg valid);

wire [3:0]cs; // one hot encoding 

wire [4:0] word_address; // 32 words of 8 bit each in a block 
//out of the 7 bit input by the user, 2 bits used to check the block , remaining for word address
integer i;

assign word_address = addr[4:0];

assign cs[0] = (addr[6:5] == 2'b00); //cs = 4'b0001
assign cs[1] = (addr[6:5] == 2'b01); //cs = 4'b0010
assign cs[2] = (addr[6:5] == 2'b10); //cs = 4'b0100
assign cs[3] = (addr[6:5] == 2'b11); //cs = 4'b1000

reg [7:0] mem_block0[0:31];
reg [7:0] mem_block1[0:31];
reg [7:0] mem_block2[0:31];
reg [7:0] mem_block3[0:31];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 32; i= i+1) begin // we cant i++ here, since it doesnt work. 
        // verilog doesnt support i++ syntactically 
        mem_block0[i] <= 0;
        mem_block1[i] <= 0;
        mem_block2[i] <= 0;
        mem_block3[i] <= 0;
        end
        end
    else 
        if(we) begin
            
            case(cs)
                4'b0001 : mem_block0[word_address] <= wdata;
                4'b0010 : mem_block1[word_address] <= wdata;
                4'b0100 : mem_block2[word_address] <= wdata;
                4'b1000 : mem_block3[word_address] <= wdata;
            endcase
        end
    end

    //read logic 
    
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin rdata <= 8'h0;
              valid <= 0;
        end
        
        else if(re) begin
            case(cs)
                4'b0001 : rdata <= mem_block0[word_address];
                4'b0010 : rdata <= mem_block1[word_address];
                4'b0100 : rdata <= mem_block2[word_address];
                4'b1000 : rdata <= mem_block3[word_address];
                
                default : rdata <= 0; 
                
                endcase
                end
                end
                endmodule
            
    
                
        
