// pipeline register between decode and execute
module DEReg
(
    // control signals to forward
    input RegWriteD,
    output reg RegWriteE,
    input MemtoRegD,
    output reg MemtoRegE,
    input MemWriteD,
    output reg MemWriteE,
    input [3:0] ALUControlD,
    output reg [3:0] ALUControlE,
    input [1:0] ALUSrcD,
    output reg [1:0] ALUSrcE,
    input RegDstD,
    output reg RegDstE,
    input StartMultD,
    output reg StartMultE,
    input MultSignD,
    output reg MultSignE,
    input [1:0] OutSelectD,
    output reg [1:0] OutSelectE,
    input jumpD,
    output reg jumpE,

    // datapath signals to forward
    input [31:0] Rd1D, // register file reg1 from decode stage
    output reg [31:0] Rd1E, // register file reg1 to execute stage
    input [31:0] Rd2D, // register file reg2 from decode stage
    output reg [31:0] Rd2E, // register file reg2 to execute stage
    input [4:0] RsD, // source reg# from decode stage
    output reg [4:0] RsE, // source reg# to execute stage
    input [4:0] RtD, // source reg# from decode stage
    output reg [4:0] RtE, // source reg# to execute stage
    input [4:0] RdD, // destination reg# from decode stage
    output reg [4:0] RdE, // destination reg# to execute stage
    input [31:0] SEimmD, // sign extended immediate from decode stage
    output reg [31:0] SEimmE, // sign extended immediate to execute stage
    input [31:0] ZEimmD, // zero extended immediate from decode stage
    output reg [31:0] ZEimmE, // zero extended immediate to execute stage
    input [31:0] ZPimmD, // zero padded immediate from decode stage
    output reg [31:0] ZPimmE, // zero padded immediate to execute stage

    input [31:0] PCPlus4D,
    output reg [31:0] PCPlus4E,

    input En,
    input Clk, // clock
    input Clr // clear
);


always @(posedge Clk)
begin
    if (Clr)
    begin
    	RegWriteE <= 0;
   	MemtoRegE <= 0;
   	MemWriteE <= 0;
    	ALUControlE <= 4'h0;
   	ALUSrcE <= 2'h0;
   	RegDstE <= 0;
    	StartMultE <= 0;
    	MultSignE <= 0;
    	OutSelectE <= 2'h0;
    	jumpE <= 0;
	PCPlus4E <= 32'h0;

    	Rd1E <= 32'h0;
    	Rd2E <= 32'h0;
    	RsE <= 5'h0;
   	RtE <= 5'h0;
    	RdE <= 5'h0;
    	SEimmE <= 32'h0;
    	ZEimmE <= 32'h0;
    	ZPimmE <= 32'h0;
    end
    else if(~En)
    begin
	RegWriteE <= RegWriteD;
        MemtoRegE <= MemtoRegD;
        MemWriteE <= MemWriteD;
        ALUControlE <= ALUControlD;
        ALUSrcE <= ALUSrcD;
        RegDstE <= RegDstD;
        StartMultE <= StartMultD;
        MultSignE <= MultSignD;
        OutSelectE <= OutSelectD;
        jumpE <= jumpD;
	PCPlus4E <= PCPlus4D;

        // get the next input on the rising clock edge
        Rd1E <= Rd1D;
        Rd2E <= Rd2D;
        RsE <= RsD;
        RtE <= RtD;
        RdE <= RdD;
        SEimmE <= SEimmD;
        ZEimmE <= ZEimmD;
	ZPimmE <= ZPimmD;
    end
end
endmodule
