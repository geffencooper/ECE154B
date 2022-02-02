// pipeline register between memory and writeback
module MWReg
(
    // control signals to forward
    input RegWriteM,
    output reg RegWriteW,
    input MemtoRegM,
    output reg MemtoRegW,

    // datapath signals to forward
    input [31:0] ReadDataM, // data to write to from memory stage (lw)
    output reg [31:0] ReadDataW, // data to write to writeback stage (lw)
    input [31:0] ExecuteOutM, // ALU/Mult Result from memory stage
    output reg [31:0] ExecuteOutW, // ALU/Mult Result to writeback stage
    input [4:0] WriteRegM, // destination reg from memory stage
    output reg [4:0] WriteRegW, // destination register to writeback stage

    input jumpM,
    output reg jumpW,
    input [31:0] PCPlus4M,
    output reg [31:0] PCPlus4W,

    input Clk,// clock
    input Clr // clear
);


always @(posedge Clk)
begin
    if(Clr)
    begin
        RegWriteW <= 0;
	MemtoRegW <= 0;
        ReadDataW <= 32'h0;
        ExecuteOutW <= 32'h0;
        WriteRegW <= 5'h0;
	jumpW <= 0;
	PCPlus4W <= 32'h0;
    end
    else
    begin
        RegWriteW <= RegWriteM;
        MemtoRegW <= MemtoRegM;

        jumpW <= jumpM;
        PCPlus4W <= PCPlus4M;

        // get the next input on the rising clock edge
        ReadDataW <= ReadDataM;
        ExecuteOutW <= ExecuteOutM;
        WriteRegW <= WriteRegM;
    end
end
endmodule
