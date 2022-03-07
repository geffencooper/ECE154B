module hazard(	input [4:0] RsE1, RtE1, RsD1, RtD1, WriteRegE1, WriteRegM1, WriteRegW1, 
		input [4:0] RsE2, RtE2, RsD2, RtD2, WriteRegE2, WriteRegM2, WriteRegW2,
		input RegWriteW1, RegWriteM1, MemtoRegM1, RegWriteE1, MemtoRegE1, MemWriteM1, ReadReady, iReadReady, WriteReady, MemWriteE1,
		input RegWriteW2, RegWriteM2, MemtoRegM2, RegWriteE2, MemtoRegE2, MemWriteM2, MemWriteE2,
		input [5:0] op, funct,
		input rst,clk, abort, Valid, writemiss, readmiss, ireadmiss, MemtoRegD, MemWriteD,
		output reg StallF, StallD, StallE, StallM, FlushE, FlushW, ForwardAD1, ForwardBD1, 
		output reg [2:0] ForwardAE1, ForwardBE1, ForwardAE2, ForwardBE2);

	reg lwstall, branchstall, multstall, rstall;
	reg branch;

	// these stay high while we have a memory access delay
	reg DMEM_STALLED;
	reg IMEM_STALLED;
	reg store_inprog;
	reg read_inprog;
	reg iread_inprog;

	// reset registers on global reset
	always @(posedge rst)
	begin
		StallF <= 0;
		StallD <= 0;
		StallE <= 0;
		FlushE <= 0;
		FlushW <= 0;
		ForwardAD1 <= 0;
		ForwardBD1 <= 0;
		ForwardAE1 <= 0;
		ForwardBE1 <= 0;
		ForwardAE2 <= 0;
		ForwardBE2 <= 0;
		lwstall <= 0;
		branchstall <= 0;
		multstall <= 0;
		branch <= 0;
		DMEM_STALLED <= 0;
		IMEM_STALLED <= 0;
		store_inprog <= 0;
		read_inprog <=0;
		iread_inprog <= 0;
	end
	
	// we only stall on the posedge because these signals stay high until the request is ready
	always @(posedge MemWriteE1, posedge MemtoRegE1, posedge MemWriteE2, posedge MemtoRegE2)//, posedge MemWriteD, posedge MemtoRegD) 
	begin
		// if a sw is already in progress (WRITING stage), then stall until it is done
		if(store_inprog || read_inprog)
		begin
			DMEM_STALLED <= 1; // should cause always block below to reevaluate
		end
	end
	
	always @(posedge ireadmiss, posedge abort)
	begin
		// if we get an abort (branch mispredict), don't try to read missed cache instr
		if(~abort)
		begin
			IMEM_STALLED <= 1;
		end
	end

	// if we do a sw (always writethrough) then set the register
	always @(posedge writemiss)
	begin		
		store_inprog <=1;
		//DMEM_STALLED <= 1;
	end
	always @(posedge readmiss)
	begin
		read_inprog <=1;
		DMEM_STALLED <= 1;
	end
	
	always @(posedge ireadmiss)
	begin
		iread_inprog <=1;
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
		StallF <= lwstall || branchstall || multstall || DMEM_STALLED || IMEM_STALLED;
		StallD <= lwstall || branchstall || multstall || DMEM_STALLED;
		StallE <= multstall || DMEM_STALLED;
		StallM <= DMEM_STALLED;

		// flush the execute stage on a decode stage stall so 'stale' register values don't propagate
		FlushE <= lwstall || branchstall;

		// flush the write stage on a data memory stall to avoid piping through incorrect control signals and data memory output
		// the Clr is synchronous so it only takes effect on the next posedge clock which is what we want because the 'current' val
		// in the Writeback reg is valid
		FlushW <= DMEM_STALLED;
	
		//Execute Stage Forwarding
		// when the source register in the execute stage matches the destination registers in the memory or writeback
		// stages, then we need to forward the most up to date value (unless it is zero). Also make sure we are writing
		// back to the register file (RegWrite) because instructions like sw don't overwrite register values. 
		
		if ((RsE1 !=0) && (RsE1==WriteRegM2) && RegWriteM2)  // if destination in Mem2
		begin
			ForwardAE1 <= 3'b100;
		end
		else if ((RsE1 !=0) && (RsE1==WriteRegM1) && RegWriteM1) // if destination in Mem1
		begin
			ForwardAE1 <= 3'b010;
		end
		else if ((RsE1 !=0) && (RsE1==WriteRegW2) && RegWriteW2)  //if destination in WB1
		begin
			ForwardAE1 <= 3'b011;
		end
		else if ((RsE1 !=0) && (RsE1==WriteRegW1) && RegWriteW1)  // if destination ni WB2
		begin
			ForwardAE1 <= 3'b001;
		end
		else							// default
		begin
			ForwardAE1 <= 3'b000;
		end


		if ((RtE1 !=0) && (RtE1==WriteRegM2) && RegWriteM2)  // if destination in Mem2
		begin
			ForwardBE1 <= 3'b100;
		end
		else if ((RtE1 !=0) && (RtE1==WriteRegM1) && RegWriteM1) // if destination in Mem1
		begin
			ForwardBE1 <= 3'b010;
		end
		else if ((RtE1 !=0) && (RtE1==WriteRegW2) && RegWriteW2)  //if destination in WB1
		begin
			ForwardBE1 <= 3'b011;
		end
		else if ((RtE1 !=0) && (RtE1==WriteRegW1) && RegWriteW1)  // if destination ni WB2
		begin
			ForwardBE1 <= 3'b001;
		end
		else							// default
		begin
			ForwardBE1 <= 3'b000;
		end
	
		if ((RsE2 !=0) && (RsE2==WriteRegM2) && RegWriteM2)  // if destination in Mem2
		begin
			ForwardAE2 <= 3'b010;
		end
		else if ((RsE2 !=0) && (RsE2==WriteRegM1) && RegWriteM1) // if destination in Mem1
		begin
			ForwardAE2 <= 3'b100;
		end
		else if ((RsE2 !=0) && (RsE2==WriteRegW2) && RegWriteW2)  //if destination in WB1
		begin
			ForwardAE2 <= 3'b011;
		end
		else if ((RsE2 !=0) && (RsE2==WriteRegW1) && RegWriteW1)  // if destination ni WB2
		begin
			ForwardAE2 <= 3'b001;
		end
		else							// default
		begin
			ForwardAE2 <= 3'b000;
		end

		if ((RtE2 !=0) && (RtE2==WriteRegM2) && RegWriteM2)  // if destination in Mem2
		begin
			ForwardBE2 <= 3'b010;
		end
		else if ((RtE2 !=0) && (RtE2==WriteRegM1) && RegWriteM1) // if destination in Mem1
		begin
			ForwardBE2 <= 3'b100;
		end
		else if ((RtE2 !=0) && (RtE2==WriteRegW2) && RegWriteW2)  //if destination in WB1
		begin
			ForwardBE2 <= 3'b011;
		end
		else if ((RtE2 !=0) && (RtE2==WriteRegW1) && RegWriteW1)  // if destination ni WB2
		begin
			ForwardBE2 <= 3'b001;
		end
		else							// default
		begin
			ForwardBE2 <= 3'b000;
		end

		//ForwardAE1 <= ((RsE1 !=0) && (RsE1==WriteRegM1) && RegWriteM1) ? 2'b10 : (((RsE1 !=0) && (RsE1==WriteRegW1) && RegWriteW1) ? 2'b01 : 2'b00);
		//ForwardBE1 <= ((RtE1 !=0) && (RtE1==WriteRegM1) && RegWriteM1) ? 2'b10 : (((RtE1 !=0) && (RtE1==WriteRegW1) && RegWriteW1) ? 2'b01 : 2'b00);
	
		//ForwardAE2 <= ((RsE2 !=0) && (RsE2==WriteRegM2) && RegWriteM2) ? 2'b10 : (((RsE2 !=0) && (RsE2==WriteRegW2) && RegWriteW2) ? 2'b01 : 2'b00);
		//ForwardBE2 <= ((RtE2 !=0) && (RtE2==WriteRegM2) && RegWriteM2) ? 2'b10 : (((RtE2 !=0) && (RtE2==WriteRegW2) && RegWriteW2) ? 2'b01 : 2'b00);


		//Decode Stage Forwarding
		// when the source register in the decode stage is the same as the destination register in the memory stage (branch)
		ForwardAD1 <= (RsD1 !=0) && (RsD1 == WriteRegM1) && RegWriteM1;
		ForwardBD1 <= (RtD1 !=0) && (RtD1 == WriteRegM1) && RegWriteM1;

		//ForwardAD2 <= (RsD2 !=0) && (RsD2 == WriteRegM2) && RegWriteM2;
		//ForwardBD2 <= (RtD2 !=0) && (RtD2 == WriteRegM2) && RegWriteM2
	
		// r type stalls
		rstall <= (RsE1 != 0) ;

		// lw Stalls, next instruction relies on destination register of lw
		lwstall <= ((RsD1==RtE1) || (RtD1==RtE1)) && MemtoRegE1;
 
		//branch stall, branch sources rely on instructions in execute (ALU) or in memory stage (lw)
		branchstall <= (branch && RegWriteE1 && ((WriteRegE1 == RsD1) || (WriteRegE1 == RtD1))) ||
					(branch && MemtoRegM1 && ((WriteRegM1 == RsD1) || (WriteRegM1 == RtD1)));
		//mult stall, multiplication not valid and a mfhi or mflo instruction shows up
		multstall <= ((funct == 6'b010000 || funct == 6'b010010)) && ~Valid && op == 6'b000000;

	end

	// once we get a ready signal from the memory we can unstall
	always @(posedge ReadReady, posedge WriteReady)
	begin
		DMEM_STALLED <= 0;
		store_inprog <= 0;
		read_inprog <= 0;
	end

	always @(posedge iReadReady, posedge abort)
	begin
		IMEM_STALLED <= 0;
		iread_inprog <=0;
	end

endmodule