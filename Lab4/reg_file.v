module reg_file
(
    input [4:0] A1_1, // read address 1 (reg num)
    input [4:0] A2_1, // read address 2 (reg num)
    output [31:0] RD1_1, // read data 1
    output [31:0] RD2_1, // read data 2
    input [4:0] WR_1,  // write address (reg num)
    input [31:0] WD_1, // write data
    input Write_enable_1, // write enable
    input [4:0] A1_2, // read address 1 (reg num)
    input [4:0] A2_2, // read address 2 (reg num)
    output [31:0] RD1_2, // read data 1
    output [31:0] RD2_2, // read data 2
    input [4:0] WR_2,  // write address (reg num)
    input [31:0] WD_2, // write data
    input Write_enable_2, // write enable
    input Rst, // synchronous reset
    input Clk // Clock
);

// used for reset to iterate through registers
integer i;

// define the memory array, 31 registers, each 32 bits wide
//reg [31:0] regs[30:0];

// Note: we made $0 a reg because it was easier to interpret when debuggin
reg [31:0] regs[31:0];

// reading from reg file happens asychronously, Note: read value only valid on the second half of cycle
//assign RD1 = (A1 != 32'h0) ? regs[A1-1] : 32'h0; // 31 registers so subtract 1 to get correct index
//assign RD2 = (A2 != 32'h0) ? regs[A2-1] : 32'h0;

assign RD1_1 = (A1_1 != 32'h0) ? regs[A1_1] : 32'h0;
assign RD2_1 = (A2_1 != 32'h0) ? regs[A2_1] : 32'h0;

assign RD1_2 = (A1_2 != 32'h0) ? regs[A1_2] : 32'h0;
assign RD2_2 = (A2_2 != 32'h0) ? regs[A2_2] : 32'h0;

// writing to memory happens synchronously on first half of cycle
always @(negedge Clk)
begin
    // check if writing data (can't write to $0) and reset not asserted
    if((Write_enable_1 || Write_enable_2) && ~Rst)
    begin
	if (WR_1 != 32'h0)
	begin
        	regs[WR_1] <= WD_1;
	end
	if (WR_2 != 32'h0)
	begin
		regs[WR_2] <= WD_2;
	end
    end
end

// asynchronous reset (whenever asserted)
always @(posedge Rst)
begin
    for(i = 0; i < 32; i = i + 1)
    begin
        regs[i] = 32'h00000000;
    end
end


endmodule
