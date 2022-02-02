// pipeline register between execute and memory
module EMReg
(
    // control signals to forward
    input RegWriteE,
    output reg RegWriteM,
    input MemtoRegE,
    output reg MemtoRegM,
    input MemWriteE,
    output reg MemWriteM,

    // datapath signals to forward
    input [31:0] ExecuteOutE, // ALU/Mult Result from execute stage
    output reg [31:0] ExecuteOutM, // ALU/Mult Result to memory stage
    input [31:0] WriteDataE, // data to write to from execute stage (sw)
    output reg [31:0] WriteDataM, // data to write to memory stage (sw)
    input [4:0] WriteRegE, // destination reg from execute stage
    output reg [4:0] WriteRegM, // destination register to memory stage

    input jumpE,
    output reg jumpM,
    input [31:0] PCPlus4E,
    output reg [31:0] PCPlus4M,

    input En, // enable
    input Clk, // clock
    input Clr // clear
);

always @(posedge Clk)
begin
    if(Clr)
    begin
	RegWriteM <= 0;
	MemtoRegM <= 0;
	MemWriteM <= 0;
        ExecuteOutM <= 32'h0;
        WriteDataM <= 32'h0;
        WriteRegM <= 5'h0;
	jumpM <= 0;
	PCPlus4M <= 32'h0;
    end
    else if(~En)
    begin
        RegWriteM <= RegWriteE;
        MemtoRegM <= MemtoRegE;
        MemWriteM <= MemWriteE;

        jumpM <= jumpE;
        PCPlus4M <= PCPlus4E;

        // get the next input on the rising clock edge
        ExecuteOutM <= ExecuteOutE;
        WriteDataM <= WriteDataE;
        WriteRegM <= WriteRegE;
    end
end
endmodule
