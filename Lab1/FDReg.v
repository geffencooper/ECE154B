// pipeline register between fetch and decode
module FDReg
(
    input [31:0] InstrF, // instruction from fetch stage
    output reg [31:0] InstrD, // instruction to decode stage
    input [31:0] PCPlus4F, // program counter fetch
    output reg [31:0] PCPlus4D, // program counter decode
    input En, // enable
    input Clk, // clock
    input Clr // clear
);

always @(posedge Clk)
begin
    if (Clr)
    begin
    	InstrD <= 31'h0;
    	PCPlus4D <= 31'h0;
    end
    else if(~En)
    begin
        InstrD <= InstrF;
	PCPlus4D <= PCPlus4F;
    end
end
endmodule
