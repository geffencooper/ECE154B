// branch target buffer
module btbuff #(parameter ROWS = 32'h00000020)  //32 entries , 2^5
(
	input [31:0] PC_current1, // current program counter in fetch stage used to index into buffer
	input [31:0] PC1, // program counter in execute stage from last branch, used to update state bits
	input [31:0] PCBranch1, // branch address, comes from execute stage, used to update entry in table
	input Branch1, // control signal from execute stage, says if branch instruction (used to evaluate prediction)
	input BranchTaken1, // control signal from execute stage, says if branch was taken (determines if prediction was correct)
	input [1:0] statein1, // latest state bit from branch history table
	output reg [31:0] PCPredict1, // the next PC to predict, PC + 4 if no brnach predicted
	output reg prediction1, // control signal, prediction lets hazard unit know if predicted a branch or not
	output reg btbhit1,

	input [31:0] PC_current2, // current program counter in fetch stage used to index into buffer
	input [31:0] PC2, // program counter in execute stage from last branch, used to update state bits
	input [31:0] PCBranch2, // branch address, comes from execute stage, used to update entry in table
	input Branch2, // control signal from execute stage, says if branch instruction (used to evaluate prediction)
	input BranchTaken2, // control signal from execute stage, says if branch was taken (determines if prediction was correct)
	input [1:0] statein2, // latest state bit from branch history table
	output reg [31:0] PCPredict2, // the next PC to predict, PC + 4 if no brnach predicted
	output reg prediction2, // control signal, prediction lets hazard unit know if predicted a branch or not
	output reg btbhit2,

	input Clk, 
	input Rst
) ;

	// states for FSM
	parameter TAKEN  = 2'b00, // strongly taken
	taken = 2'b01, // weakly taken
	nottaken = 2'b10, // weakly not taken
	NOTTAKEN = 2'b11; // stringly not taken

	// branch target buffer table
	reg [72:0] buff[0:ROWS-1];  // 1 Valid Bit, 32 PC bits, 32 PC Prediction bits, 2 state bits
	reg [1:0] global_state;

	integer i;
	always @(posedge Rst)  
	begin		
		btbhit1 <= 0;
		prediction1 <= 0;
		PCPredict1 <= 32'b0;
		btbhit2 <= 0;
		prediction2 <= 0;
		PCPredict2 <= 32'b0;
		global_state <= 2'b11;

		for (i=0;i<ROWS;i=i+1)
		begin
			buff[i] <= {1'b0,32'b1,32'b0,8'b11111111}; //on a reset, default all to Strongly Not taken
		end

	end


	// index into the branch target buffer which has 2^5 entries (lower 5 bits of PC not including byte offset)
	wire [4:0] buff_offset1; // offset for getting prediction (execute stage) 
	wire [4:0] buff_offset_current1; // offset updating entry (fetch stage)

	wire [4:0] buff_offset2; // offset for getting prediction (execute stage) 
	wire [4:0] buff_offset_current2; // offset updating entry (fetch stage)

	assign buff_offset1 = PC1[6:2]; // lower 5 bits from exec stage PC
	assign buff_offset_current1 = PC_current1[6:2]; // lower 5 bits from fetch stage PC

	assign buff_offset2 = PC2[6:2]; // lower 5 bits from exec stage PC
	assign buff_offset_current2 = PC_current2[6:2]; // lower 5 bits from fetch stage PC

	// if there was a branch instruction, need to update the corresponding entry
	always @(posedge Clk)
	begin
		if(Branch1)
		begin
		buff[buff_offset1][72] <= 1; // make the entry valid
		buff[buff_offset1][71:40] <= PC1; // set the PC corresponding to the branch
		buff[buff_offset1][39:8] <= PCBranch1; // set the branch taken address
		case(global_state)
			00: buff[buff_offset1][1:0] <= statein1; // set the state bits
			01: buff[buff_offset1][3:2] <= statein1; // set the state bits
			10: buff[buff_offset1][5:4] <= statein1; // set the state bits
			11: buff[buff_offset1][7:6] <= statein1; // set the state bits
		endcase
		global_state <= {global_state[0],~BranchTaken1};
		end

		if(Branch2)
		begin
		buff[buff_offset2][72] <= 1; // make the entry valid
		buff[buff_offset2][71:40] <= PC2; // set the PC corresponding to the branch
		buff[buff_offset2][39:8] <= PCBranch2; // set the branch taken address
		case(global_state)
			00: buff[buff_offset2][1:0] <= statein2; // set the state bits
			01: buff[buff_offset2][3:2] <= statein2; // set the state bits
			10: buff[buff_offset2][5:4] <= statein2; // set the state bits
			11: buff[buff_offset2][7:6] <= statein2; // set the state bits
		endcase
		// path1 has priority unless branch1 is not taken, then listen to next instruction which is bottom path
		if(~BranchTaken1)
		begin
			global_state <= {global_state[0],~BranchTaken2};
		end
		end

	end

	// every time the current program counter changes, generate the next PC
	always @(PC_current1)
	begin
		// if we find the current PC in the buffer, it is valid, and the state bits signify a taken 
		if (buff[buff_offset_current1][72] && (PC_current1 == buff[buff_offset_current1][71:40]) && ~buff[buff_offset_current1][(1 + (global_state<<1))])
		begin
			// branch taken predicted, get the address
			PCPredict1 <= buff[buff_offset_current1][39:8];
			
			// tell the hazard unit we predicted a branch taken in case we need to flush
			prediction1 <= 1;
			btbhit1 <= 1;
			
		end
		// otherwise (we didn't find the branch in the buffer)
		else
		begin
			// just go to PC + 4
			//PCPredict <= PC + 32'b4;

			// tell the hazard unit we predicted a branch not taken in case we need to flush
			prediction1 <= 0;
			btbhit1<=0;
		end
	end

	always @(PC_current2)
	begin
		// if first path had a branch taken, this branch is not valid anymore (instruction got skiped)
		if(~prediction1)
		begin
			// if we find the current PC in the buffer, it is valid, and the state bits signify a taken 
			if (buff[buff_offset_current2][72] && (PC_current2 == buff[buff_offset_current2][71:40]) && ~buff[buff_offset_current2][(1 + (global_state<<1))])
			begin
				// branch taken predicted, get the address
				PCPredict2 <= buff[buff_offset_current2][39:8];
				
				// tell the hazard unit we predicted a branch taken in case we need to flush
				prediction2 <= 1;
				btbhit2 <= 1;
				
			end
			// otherwise (we didn't find the branch in the buffer)
			else
			begin
				// just go to PC + 4
				//PCPredict <= PC + 32'b4;
	
				// tell the hazard unit we predicted a branch not taken in case we need to flush
				prediction2 <= 0;
				btbhit2<=0;
			end
		end
	end

endmodule

module twolevel_bp #(parameter ROWS = 32'h00000080) // 128 entries, 2^7
(
	input Clk, Rst,
	input [31:0] PC1, // propagated program counter to execute stage
	input Branch1, // control signal from decode stage, says if there was a branch
	input BranchTaken1, // control signal from decode stage, says if the branch was taken
	output reg [1:0] stateout1, // 2 bit predictor bits (current pediciton state)
	input [31:0] PC2, // propagated program counter to execute stage
	input Branch2, // control signal from decode stage, says if there was a branch
	input BranchTaken2, // control signal from decode stage, says if the branch was taken
	output reg [1:0] stateout2 // 2 bit predictor bits (current pediciton state)
);

	parameter TAKEN  = 2'b00, // strongly taken
	taken = 2'b01, // weakly taken
	nottaken = 2'b10, // weakly not taken
	NOTTAKEN = 2'b11; // stringly not taken

	reg [1:0] global_state;

	reg [7:0] bhtable[0:ROWS-1][0:3]; 

	wire [6:0] table_offset1;
	wire [6:0] table_offset2;

	// since byte addressable, ignore lower 2 bits because always 0
	assign table_offset1 = PC1[8:2]; //seven bits to select one of the 2^7 table entries
	assign table_offset2 = PC2[8:2]; //seven bits to select one of the 2^7 table entries
 
	integer i, j;
	// reset the branch history table
	always @(posedge Rst)  
	begin		
		stateout1 <= 2'b11;	
		stateout2 <= 2'b11;	
		for (i=0;i<ROWS;i=i+1)
		begin
			for (j=0;j<4;j=j+1)
			begin
			bhtable[i][j] <= 2'b11; //on a reset, default all to Strongly Not taken
			end
		end
		global_state <= 2'b11;
	end

	always @(posedge Branch1)
	begin
		// 'saturating counter' to implement states
		case (bhtable[table_offset1][global_state])
			TAKEN : bhtable[table_offset1][global_state] <= (~BranchTaken1) ? (taken) : (TAKEN);
			taken : bhtable[table_offset1][global_state]  <= (~BranchTaken1) ? (nottaken) : (TAKEN);
			nottaken : bhtable[table_offset1][global_state]  <= (~BranchTaken1) ? (NOTTAKEN) : (taken);
			NOTTAKEN : bhtable[table_offset1][global_state]  <= (~BranchTaken1) ? (NOTTAKEN) : (nottaken);
		endcase

		// output the new state bits
		stateout1 = bhtable[table_offset1][global_state];

		global_state = {global_state[0],~BranchTaken1};

	end 

	always @(posedge Branch2)
	begin
		if(~BranchTaken1)
			begin
			// 'saturating counter' to implement states
			case (bhtable[table_offset2][global_state])
				TAKEN : bhtable[table_offset2][global_state] <= (~BranchTaken2) ? (taken) : (TAKEN);
				taken : bhtable[table_offset2][global_state]  <= (~BranchTaken2) ? (nottaken) : (TAKEN);
				nottaken : bhtable[table_offset2][global_state]  <= (~BranchTaken2) ? (NOTTAKEN) : (taken);
				NOTTAKEN : bhtable[table_offset2][global_state]  <= (~BranchTaken2) ? (NOTTAKEN) : (nottaken);
			endcase
	
			// output the new state bits
			stateout2 = bhtable[table_offset2][global_state];
	
			global_state = {global_state[0],~BranchTaken2};
		end

	end 

endmodule