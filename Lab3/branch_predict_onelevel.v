// branch target buffer
module btbuff #(parameter ROWS = 32'h00000020)  //32 entries , 2^5
(
	input [31:0] PC_current, // current program counter in fetch stage used to index into buffer
	input [31:0] PC, // program counter in execute stage from last branch, used to update state bits
	input [31:0] PCBranch, // branch address, comes from execute stage, used to update entry in table
	input Branch, // control signal from execute stage, says if branch instruction (used to evaluate prediction)
	input BranchTaken, // control signal from execute stage, says if branch was taken (determines if prediction was correct)
	input Clk, 
	input Rst, 
	input [1:0] statein, // latest state bit from branch history table
	output [31:0] PCPredict, // the next PC to predict, PC + 4 if no brnach predicted
	output prediction // control signal, prediction lets hazard unit know if predicted a branch or not
) 

	// states for FSM
	parameter TAKEN  = 2'b00, // strongly taken
	taken = 2'b01, // weakly taken
	nottaken = 2'b10, // weakly not taken
	NOTTAKEN = 2'b11; // stringly not taken

	// branch target buffer table
	reg [66:0] buff[0:ROWS-1];  // 1 Valid Bit, 32 PC bits, 32 PC Prediction bits, 2 state bits

	// index into the branch target buffer which has 2^5 entries (lower 5 bits of PC not including byte offset)
	wire [4:0] buff_offset; // offset for getting prediction (execute stage) 
	wire [4:0] buff_offset_current; // offset updating entry (fetch stage)

	assign buff_offset <= PC[6:2]; // lower 5 bits from exec stage PC
	assign buff_offset_current <= PC_current[6:2]; // lower 5 bits from fetch stage PC

	// if there was a branch instruction, need to update the corresponding entry
	always @(posedge Branch)
	begin
		buff[buff_offset][66] <= 1; // make the entry valid
		buff[buff_offset][65:34] <= PC; // set the PC corresponding to the branch
		buff[buff_offset][33:2] <= PCBranch; // set the branch taken address
		buff[buff_offset][1:0] <= statein; // set the state bits
	end

	// every time the current program counter changes, generate the next PC
	always @(PC_current)
	begin
		// if we find the current PC in the buffer, it is valid, and the state bits signify a taken 
		if (buff[buff_offset_current][66] && (PC_current == buff[buff_offset_current][65:34]) && ~buff[buff_offset_current][1])
		begin
			// branch taken predicted, get the address
			PCPredict <= buff[buff_offset_current][33:2];
			
			// tell the hazard unit we predicted a branch taken in case we need to flush
			prediction <= 1;
			
		end
		// otherwise (we didn't find the branch in the buffer)
		else
		begin
			// just go to PC + 4
			PCPredict <= PC + 32'b4;

			// tell the hazard unit we predicted a branch not taken in case we need to flush
			prediction <= 0;
		end
	end

endmodule

// branch history table
module bht #(parameter ROWS = 32'h00000080) // 128 entries, 2^7
(
	input [31:0] PC, // propagated program counter to execute stage
	input Branch, // control signal from decode stage, says if there was a branch
	input BranchTaken, // control signal from decode stage, says if the branch was taken
	input Clk,
	input Rst, 
	output [1:0] stateout // 2 bit predictor bits (current pediciton state)
);

	// table of 2 bit states for each (of 128) local branch
	reg [1:0] bhtable[0:ROWS-1];

	// idx into the table is the lower 7 bits of the program counter
	wire [6:0] table_offset;

	// since byte addressable, ignore lower 2 bits because always 0
	assign table_offset <= PC[8:2]; //seven bits to select one of the 2^7 table entries

	parameter TAKEN  = 2'b00, // strongly taken
	taken = 2'b01, // weakly taken
	nottaken = 2'b10, // weakly not taken
	NOTTAKEN = 2'b11; // stringly not taken

	// reset the branch history table
	always @(posedge Rst)  
	begin			
		for (i=0;i<ROWS;i=i+1)
		begin
			bhtable[i] <= 2'b11; //on a reset, default all to Strongly Not taken
		end

	end

	// on a branch, update the state bits and send the update to the branch target buffer
	always @(posedge Branch)
	begin
		// 'saturating counter' to implement states
		case (bhtable[table_offset])
		begin
			TAKEN : bhtable[table_offset] <= (~branch) ? (taken) : (TAKEN);
			taken : bhtable[table_offset] <= (~branch) ? (nottaken) : (TAKEN);
			nottaken : bhtable[table_offset] <= (~branch) ? (NOTTAKEN) : (taken);
			NOTTAKEN : bhtable[table_offset] <= (~branch) ? (NOTTAKEN) : (nottaken);
		endcase

		// output the new state bits
		stateout <= bhtable[table_offset];
	end 

endmodule