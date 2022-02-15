module btbuff #(parameter ROWS = 32'h00000020)  //32 , 2^5
(input [31:0] PC, PCBranch, input Branch, BranchTaken, Clk, Rst, input [1:0] statein, 
		output [31:0] PCPredict)

	reg [65:0] buff[0:ROWS-1];


endmodule

module bht #(parameter ROWS = 32'h00000080)
(input [31:0] PC, input Branch, BranchTaken, Clk, Rst, output [1:0] stateout);

	reg [1:0] bhtable[0:ROWS-1];

	always @(posedge Rst)  //want everything set to zero on a reset
	begin			// states set to 11 on reset
		state <= INIT; //ad other things on reset
		for (i=0;i<ROWS;i=i+1)
		begin
			way1[i] <= 2'b11;
		end

	end

endmodule