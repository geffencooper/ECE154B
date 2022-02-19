module btbuff #(parameter ROWS = 32'h00000020)  //32 , 2^5
(input [31:0] PC_current, PC, PCBranch, input Branch, BranchTaken, Clk, Rst, input [1:0] statein, 
		output [31:0] PCPredict, output prediction) //prediction lets hazard unit know if predicted a branch or not

	parameter TAKEN  = 2'b00, // initial, wait for start signal
	nottaken = 2'b01, // if memtoreg == 1, and a miss
	taken = 2'b10, // if signed, first make numbers positive
	NOTTAKEN = 2'b11; // do the multiplication

	reg [66:0] buff[0:ROWS-1];  // 1 Valid Bit, 32 PC bit, 32 PC Predicted bit, 2 state bit

	wire [5:0] buff_offset;
	wire [5:0] buff_offset_current;

	assign buff_offset <= PC[6:2];
	assign buff_offset_current <= PC_current[6:2];

	always @(posedge Branch)
	begin
		buff[buff_offset][66] <= 1;
		buff[buff_offset][65:34] <= PC;
		buff[buff_offset][33:2] <= PCBranch;
		buff[buff_offset][1:0] <= statein;
	end

	always @(posedge PC_current)
	begin
		if ((PC_current == buff[buff_offset_current][65:34]) && ~state[0] && buff[buff_offset_current][66])
		begin
			PCPredict <= buff[buff_offset_current][33:2];
			if (
			prediction <= 1;
			
		end
		else
		begin
			PCPredict <= PC + 32'b4;
			prediction <= 0;
		end
	end

endmodule

module bht #(parameter ROWS = 32'h00000080)
(input [31:0] PC, input Branch, BranchTaken, Clk, Rst, output [1:0] stateout);

	reg [1:0] bhtable[0:ROWS-1];
	wire [6:0] table_offset;

	assign table_offset <= PC[8:2]; //seven bits to select one of the 2^7 table entries

 

	always @(posedge Rst)  
	begin			
		for (i=0;i<ROWS;i=i+1)
		begin
			bhtable[i] <= 2'b11; //on a reset, default all to Strongly Not taken
		end

	end

	always @(posedge Branch)
	begin
		bhtable[table_offset] <= bhtable[table_offset][0],~BranchTaken];
		stateout <= bhtable[table_offset];
	end 

	

endmodule