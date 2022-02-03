module hazard(	input [4:0] RsE, RtE, RsD, RtD, WriteRegE, WriteRegM, WriteRegW, 
		input RegWriteW, RegWriteM, MemtoRegM, RegWriteE, MemtoRegE, MemWriteM,
		input [5:0] op, funct,
		input rst,clk, Valid,
		output reg StallF, StallD, StallE, StallM, FlushE, ForwardAD, ForwardBD, 
		output reg [1:0] ForwardAE, ForwardBE);

	reg lwstall, branchstall, multstall;
	reg branch;

	// we need to keep track of memory delays
	reg [4:0] dmem_stall_count;
	reg [4:0] imem_stall_count;

	// these stay high while we have a memory access delay
	reg DMEM_STALLED;
	reg IMEM_STALLED;

	// reset registers on global reset
	always @(posedge rst)
	begin
		StallF <= 0;
		StallD <= 0;
		StallE <= 0;
		FlushE <= 0;
		ForwardAD <= 0;
		ForwardBD <= 0;
		ForwardAE <= 0;
		ForwardBE <= 0;
		lwstall <= 0;
		branchstall <= 0;
		multstall <= 0;
		branch <= 0;
		dmem_stall_count <= 5'b00000;
		imem_stall_count <= 5'b00000;
		DMEM_STALLED <= 0;
		IMEM_STALLED <= 0;
	end
	
	// we only stall on the posedge because these signals stay high until we unstall which takes a cycle
	always @(posedge MemWriteM, posedge MemtoRegM)
	begin
		// if data memory not stalling and we want to do a SW/LW, then stall
		if(~DMEM_STALLED)
		begin
			DMEM_STALLED <= 1; // should cause always block below to reevaluate
			dmem_stall_count <= dmem_stall_count + 1; // increment now because not 'observed' till next posedge
		end
	end

	// we wanted our hazards to resolve immediately but decided to make them registers instead of
	// wires because we were getting 'unknown' spike values on clock edges because the input signals
	// are in a brief state of uncertainty. To fix this bug we made them registers and had them change when
	// any of the inputs change
	always @(*)
	begin
		// branch on bne or beq instructions
		branch <= (op == 6'b000100 || op == 6'b000101) ? 1 : 0;
	
		// a stall in one stage should stall the stages before it
		StallF <= lwstall || branchstall || multstall || DMEM_STALLED;
		StallD <= lwstall || branchstall || multstall || DMEM_STALLED;
		StallE <= multstall || DMEM_STALLED;
		StallM <= DMEM_STALLED;

		// flush the execute stage on a decode stage stall so 'stale' register values don't propagate
		FlushE <= lwstall || branchstall;
	
		//Execute Stage Forwarding
		// when the source register in the execute stage matches the destination registers in the memory or writeback
		// stages, then we need to forward the most up to date value (unless it is zero). Also make sure we are writing
		// back to the register file (RegWrite) because instructions like sw don't overwrite register values. 
		ForwardAE <= ((RsE !=0) && (RsE==WriteRegM) && RegWriteM) ? 2'b10 : (((RsE !=0) && (RsE==WriteRegW) && RegWriteW) ? 2'b01 : 2'b00);
		ForwardBE <= ((RtE !=0) && (RtE==WriteRegM) && RegWriteM) ? 2'b10 : (((RtE !=0) && (RtE==WriteRegW) && RegWriteW) ? 2'b01 : 2'b00);
	
		//Decode Stage Forwarding
		// when the source register in the decode stage is the same as the destination register in the memory stage (branch)
		ForwardAD <= (RsD !=0) && (RsD == WriteRegM) && RegWriteM;
		ForwardBD <= (RtD !=0) && (RtD == WriteRegM) && RegWriteM;
	
		// lw Stalls, next instruction relies on destination register of lw
		lwstall <= ((RsD==RtE) || (RtD==RtE)) && MemtoRegE;
	
		//branch stall, branch sources rely on instructions in execute (ALU) or in memory stage (lw)
		branchstall <= (branch && RegWriteE && ((WriteRegE == RsD) || (WriteRegE == RtD))) ||
					(branch && MemtoRegM && ((WriteRegM == RsD) || (WriteRegM == RtD)));
		//mult stall, multiplication not valid and a mfhi or mflo instruction shows up
		multstall <= ((funct == 6'b010000 || funct == 6'b010010)) && ~Valid && op == 6'b000000;
	end

	// we need to count the delay and unstall once its over
	always @(posedge clk)
	begin
		// if stalled, increment the cycle count
		if(DMEM_STALLED && dmem_stall_count < 8'h14)
		begin
			dmem_stall_count <= dmem_stall_count + 1;
		end
		// unstall and reset counter after 20 cycles
		else if(DMEM_STALLED && dmem_stall_count == 8'h14)
		begin
			dmem_stall_count <= 0;
			DMEM_STALLED <= 0;
		end
	end
endmodule