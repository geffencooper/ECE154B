module datapath (input CLK, RESET);

	// fetch and decode wires
	wire [31:0] InstrF1, PCPlus8F1, PCBranchD1, PCInter1, PCJump1, PCprime1, PCF1, InstrD1, PCPlus8D1;
	wire PCSrcD1, jumpD1, StallF1, FlushD1, StallD1, StallE1, StallM1;
	wire [31:0] liljump1, PCInter21, PCPredict1;
	wire ireadmiss1, ireadready1;
	wire [31:0] iaddy1;
	wire [4095:0] idata1;
	wire predictionF1;
	wire [1:0] branchstate1;

	wire [31:0] InstrF2, PCPlus8F2, PCBranchD2, PCInter2, PCJump2, PCprime2, PCF2, InstrD2, PCPlus8D2;
	wire PCSrcD2, jumpD2, StallF2, FlushD2, StallD2, StallE2, StallM2;
	wire [31:0] liljump2, PCInter22, PCPredict2;
	wire ireadmiss2, ireadready2;
	wire [31:0] iaddy2;
	wire [4095:0] idata2;
	wire predictionF2;
	wire [1:0] branchstate2;
	
	// decode and execute wires 1
	wire MemtoRegD1, MemWriteD1, RegDstD1, RegWriteD1;
	wire out_selectD1;
	wire [1:0] ALUSrcD1;
	wire [3:0] ALUControlD1;
	wire [31:0] RD1D1, RD2D1, ResultW1, interResultW1;
	wire [4:0] WriteRegW1;
	wire [31:0] SEimmD1, ZEimmD1, ZPimmD1, SEimmshftD1, SEimmE1, ZEimmE1, ZPimmE1;
	wire [31:0] ExecuteOutM1, branch_checkA1, branch_checkB1;
	wire ForwardAD1, ForwardBD1;
	wire [31:0] RD1E1, RD2E1; 
	wire [4:0] RsE1, RtE1, RdE1;
	wire FlushE1, btbhit1;
	wire isBranchD1, isBranchE1, predictionD1, PCSrcE1;
	wire [31:0] PCE1, PCD1, PCBranchE1;

	// decode and execute wires 2
	wire MemtoRegD2, MemWriteD2, RegDstD2, RegWriteD2;
	wire out_selectD2;
	wire [1:0] ALUSrcD2;
	wire [3:0] ALUControlD2;
	wire [31:0] RD1D2, RD2D2, ResultW2, interResultW2;
	wire [4:0] WriteRegW2;
	wire [31:0] SEimmD2, ZEimmD2, ZPimmD2, SEimmshftD2, SEimmE2, ZEimmE2, ZPimmE2;
	wire [31:0] ExecuteOutM2, branch_checkA2, branch_checkB2;
	wire ForwardAD2, ForwardBD2;
	wire [31:0] RD1E2, RD2E2; 
	wire [4:0] RsE2, RtE2, RdE2;
	wire FlushE2, btbhit2;
	wire isBranchD2, isBranchE2, predictionD2, PCSrcE2;
	wire [31:0] PCE2, PCD2, PCBranchE2;

	wire abort, abort2;

	// execute and memory wires1
	wire MemtoRegE1, MemWriteE1, RegDstE1, RegWriteE1, jumpE1, jumpM1, jumpW1;
	wire out_selectE1;
	wire [1:0] ALUSrcE1;
	wire [3:0] ALUControlE1;
	//wire [4:0] prejumpWriteRegE;
	wire [4:0] WriteRegE1, WriteRegM1;
	wire [2:0] ForwardAE1, ForwardBE1;
	wire [31:0] SrcAE1, SrcBE1, WriteDataE1, ALUOutE1, WriteDataM1, PCPlus8E1, PCPlus8M1, PCPlus8W1;
	wire [31:0] ExecuteOutE1;

	// execute and memory wires2
	wire MemtoRegE2, MemWriteE2, RegDstE2, RegWriteE2, jumpE2, jumpM2, jumpW2;
	wire out_selectE2;
	wire [1:0] ALUSrcE2;
	wire [3:0] ALUControlE2;
	//wire [4:0] prejumpWriteRegE;
	wire [4:0] WriteRegE2, WriteRegM2;
	wire [2:0] ForwardAE2, ForwardBE2;
	wire [31:0] SrcAE2, SrcBE2, WriteDataE2, ALUOutE2, WriteDataM2, PCPlus8E2, PCPlus8M2, PCPlus8W2;
	wire [31:0] ExecuteOutE2;

	// memory and writeback wires 1
	wire MemtoRegM1, MemWriteM1, RegWriteM1;
	wire [31:0] ReadDataM1, ExecuteOutW1;

	wire MemtoRegW1, RegWriteW1;
	wire FlushW1;
	wire [31:0] ReadDataW1;

	wire [31:0] addymem1, datawrite1;
	wire [127:0] datareadmiss1;
	wire ReadReady1, WriteReady1, readmiss1, memwritethru1;

	// memory and writeback wires 2
	wire MemtoRegM2, MemWriteM2, RegWriteM2;
	wire [31:0] ReadDataM2, ExecuteOutW2;

	wire MemtoRegW2, RegWriteW2;
	wire FlushW2;
	wire [31:0] ReadDataW2;

	wire [31:0] addymem2, datawrite2;
	wire [127:0] datareadmiss2;
	wire ReadReady2, WriteReady2, readmiss2, memwritethru2;

//-----------------FETCH----------------//
	// PC Selection
	mux2 branchmux1( .d0(PCInter21) , .d1(PCBranchD1), .s((PCSrcD1 ^ predictionD1)), .y(PCprime1));
	mux2 jumpmux1( .d0(PCPlus8F1), .d1(PCJump1), .s(jumpD1), .y(PCInter1));

	mux2 predictmux1( .d0(PCInter1), .d1(PCPredict1), .s(btbhit1), .y(PCInter21));

	btbuff_ btbuffer1(.PC_current(PCF1), .PC(PCE1), .PCBranch(PCBranchE1), .Branch(isBranchE1), .BranchTaken(PCSrcE1), .Clk(CLK), .Rst(RESET), 
		.statein(branchstate1), .PCPredict(PCPredict1), .prediction(predictionF1), .btbhit(btbhit1)); //PCPredict is output to the new mux
	
	// PC Selection
	mux2 branchmux2( .d0(PCInter22) , .d1(PCBranchD2), .s((PCSrcD2 ^ predictionD2)), .y(PCprime2));
	mux2 jumpmux2( .d0(PCPlus8F2), .d1(PCJump2), .s(jumpD2), .y(PCInter2));

	mux2 predictmux2( .d0(PCInter2), .d1(PCPredict2), .s(btbhit2), .y(PCInter22));

        // pc register and instruction memory
	register #(32) PCreg1( .D(PCprime1), .Q(PCF1), .En(StallF1), .Clk(CLK), .Clr(RESET));
	
	assign abort = PCSrcD1 ^ predictionD1;

	icache instr_cache(.addy1(PCF1), .datareadmiss(idata1),. readready(ireadready1), 
			   .Rst(RESET), .Clk(CLK), .abort(abort),
			   .instr1(InstrF1), .address1(iaddy1), .readmiss(ireadmiss1),
			   .addy2(PCF2), .instr2(InstrF2));

	inst_memory #(15) imem( .Address(iaddy1), .Read_data(idata1), .ReadReady(ireadready1), .ReadMiss(ireadmiss1), 
				.abort(abort), .Clk(CLK), .Rst(RESET));


	adder plus8( .a(PCF1), .b(32'b1000), .y(PCPlus8F1));
	adder plus4( .a(PCF1), .b(32'b100), .y(PCF2));

        // flush fetch stage when have a jump instruction or we incorrectly guessed the branch result (prediction and ground truth should both be 0 or 1)
	assign FlushD1 = jumpD1 || (PCSrcD1^predictionD1);

	// Fetch-Decode pipeline register, clear on a flush or reset
	FDReg fdreg1( .InstrF(InstrF1), .InstrD(InstrD1), .PCPlus4F(PCPlus8F1), .PCPlus4D(PCPlus8D1), .PCF(PCF1), .PCD(PCD1), 
			.predictionF(predictionF1), .predictionD(predictionD1), .En(StallD1), .Clk(CLK), .Clr(FlushD1 || RESET));
	
        //jump target addy
	shftr jumpshift1( .a({6'b0,InstrD1[25:0]}), .y(liljump1));
	assign PCJump1 = {PCPlus8F1[31:28],liljump1[27:0]};

	// Fetch-Decode pipeline register, clear on a flush or reset
	FDReg fdreg2( .InstrF(InstrF2), .InstrD(InstrD2), .PCPlus4F(PCPlus8F2), .PCPlus4D(PCPlus8D2), .PCF(PCF2), .PCD(PCD2), 
			.predictionF(predictionF1), .predictionD(predictionD2), .En(StallD1), .Clk(CLK), .Clr(FlushD1 || RESET)); //FlushD2 and StallD2 and predictionF2
	
        //jump target addy
	shftr jumpshift2( .a({6'b0,InstrD2[25:0]}), .y(liljump2));
	assign PCJump2 = {PCPlus8F2[31:28],liljump2[27:0]};

	

	
	assign abort2 = PCSrcD2 ^ predictionD2;


        // flush fetch stage when have a jump instruction or we incorrectly guessed the branch result (prediction and ground truth should both be 0 or 1)
	assign FlushD2 = jumpD2 || (PCSrcD2^predictionD2);


//-----------------DECODE----------------//
	
	// control logic
	controller ctrlr1(	.op(InstrD1[31:26]), .funct(InstrD1[5:0]), .memtoreg(MemtoRegD1), .memwrite(MemWriteD1), .alusrc(ALUSrcD1), 
				.out_select(out_selectD1), 
				.regdst(RegDstD1), .regwrite(RegWriteD1), .jump(jumpD1), .alucontrol(ALUControlD1));

	controller ctrlr2(	.op(InstrD2[31:26]), .funct(InstrD2[5:0]), .memtoreg(MemtoRegD2), .memwrite(MemWriteD2), .alusrc(ALUSrcD2), 
				.out_select(out_selectD2), 
				.regdst(RegDstD2), .regwrite(RegWriteD2), .jump(jumpD2), .alucontrol(ALUControlD2));

	// register file
	reg_file regfile( .A1_1(InstrD1[25:21]), .A2_1(InstrD1[20:16]), .RD1_1(RD1D1), .RD2_1(RD2D1), .WR_1(WriteRegW1), .WD_1(ResultW1), .Write_enable_1(RegWriteW1),
			.A1_2(InstrD2[25:21]), .A2_2(InstrD2[20:16]), .RD1_2(RD1D2), .RD2_2(RD2D2), .WR_2(WriteRegW2), .WD_2(ResultW2), .Write_enable_2(RegWriteW2), 
			.Rst(RESET), .Clk(CLK));
	
	//immediate handling
	signext signextend1( .a(InstrD1[15:0]), .y(SEimmD1));
	zeroext zeroextend1( .a(InstrD1[15:0]), .y(ZEimmD1));
	zeropad zeropadder1( .a(InstrD1[15:0]), .y(ZPimmD1));

	signext signextend2( .a(InstrD2[15:0]), .y(SEimmD2));
	zeroext zeroextend2( .a(InstrD2[15:0]), .y(ZEimmD2));
	zeropad zeropadder2( .a(InstrD2[15:0]), .y(ZPimmD2));
	
	// handle branch target address
	shftr branchshift1( .a(SEimmD1), .y(SEimmshftD1));
	adder btadder1( .a(SEimmshftD1), .b(PCPlus8D1), .y(PCBranchD1));

	shftr branchshift2( .a(SEimmD2), .y(SEimmshftD2));
	adder btadder2( .a(SEimmshftD2), .b(PCPlus8D2), .y(PCBranchD2));
	
	// muxes for branch conditions to get most up to date registers
	mux2 branchfwda( .d0(RD1D1), .d1(ExecuteOutM1), .s(ForwardAD1), .y(branch_checkA1));
	mux2 branchfwdb( .d0(RD2D1), .d1(ExecuteOutM1), .s(ForwardBD1), .y(branch_checkB1));


	// branch comparator
	equality eq1( .op(InstrD1[31:26]), .srca(branch_checkA1), .srcb(branch_checkB1), .StallD(StallD1), .eq_ne(PCSrcD1), .branch(isBranchD1));

	equality eq2( .op(InstrD2[31:26]), .srca(branch_checkA2), .srcb(branch_checkB2), .StallD(StallD2), .eq_ne(PCSrcD2), .branch(isBranchD2));
	
	// decode execute pipeline register, clear on a flush or reset
	DEReg dereg1( 	.RegWriteD(RegWriteD1), .RegWriteE(RegWriteE1), .MemtoRegD(MemtoRegD1), .MemtoRegE(MemtoRegE1), .MemWriteD(MemWriteD1), 
			.MemWriteE(MemWriteE1), .ALUControlD(ALUControlD1), .ALUControlE(ALUControlE1), .ALUSrcD(ALUSrcD1), .ALUSrcE(ALUSrcE1), 
			.RegDstD(RegDstD1), .RegDstE(RegDstE1), .OutSelectD(out_selectD1), .OutSelectE(out_selectE1), .jumpD(jumpD1), .jumpE(jumpE1),
			.Rd1D(RD1D1), .Rd2D(RD2D1), .Rd1E(RD1E1), .Rd2E(RD2E1), .RsD(InstrD1[25:21]), .RsE(RsE1), .RtD(InstrD1[20:16]), 
			.RtE(RtE1), .RdD(InstrD1[15:11]), . RdE(RdE1), .SEimmD(SEimmD1), .SEimmE(SEimmE1), .ZEimmD(ZEimmD1), .ZEimmE(ZEimmE1),
			.ZPimmD(ZPimmD1), .ZPimmE(ZPimmE1), .PCPlus4D(PCPlus8D1), .PCPlus4E(PCPlus8E1), .Clk(CLK), .Clr(FlushE1 || RESET), .En(StallE1),
			.PCE(PCE1), .PCD(PCD1), .isBranchE(isBranchE1), .isBranchD(isBranchD1), .PCSrcE(PCSrcE1), .PCSrcD(PCSrcD1), .PCBranchE(PCBranchE1), .PCBranchD(PCBranchD1));

	DEReg dereg2( 	.RegWriteD(RegWriteD2), .RegWriteE(RegWriteE2), .MemtoRegD(MemtoRegD2), .MemtoRegE(MemtoRegE2), .MemWriteD(MemWriteD2), 
			.MemWriteE(MemWriteE2), .ALUControlD(ALUControlD2), .ALUControlE(ALUControlE2), .ALUSrcD(ALUSrcD2), .ALUSrcE(ALUSrcE2), 
			.RegDstD(RegDstD2), .RegDstE(RegDstE2), .OutSelectD(out_selectD2), .OutSelectE(out_selectE2), .jumpD(jumpD2), .jumpE(jumpE2),
			.Rd1D(RD1D2), .Rd2D(RD2D2), .Rd1E(RD1E2), .Rd2E(RD2E2), .RsD(InstrD2[25:21]), .RsE(RsE2), .RtD(InstrD2[20:16]), 
			.RtE(RtE2), .RdD(InstrD2[15:11]), . RdE(RdE2), .SEimmD(SEimmD2), .SEimmE(SEimmE2), .ZEimmD(ZEimmD2), .ZEimmE(ZEimmE2),
			.ZPimmD(ZPimmD2), .ZPimmE(ZPimmE2), .PCPlus4D(PCPlus8D2), .PCPlus4E(PCPlus8E2), .Clk(CLK), .Clr(FlushE1 || RESET), .En(StallE1), //FlushE2, StallE2
			.PCE(PCE2), .PCD(PCD2), .isBranchE(isBranchE2), .isBranchD(isBranchD2), .PCSrcE(PCSrcE2), .PCSrcD(PCSrcD2), .PCBranchE(PCBranchE2), .PCBranchD(PCBranchD2));

//-----------------EXECUTE----------------//

	bht_ ranch_predictor(.PC(PCE1), .Branch(isBranchE1), .BranchTaken(PCSrcE1), .Clk(CLK), .Rst(RESET), .stateout(branchstate1));

	// muxes for determining the destination register
	mux2 #(5) regdest1( .d0(RtE1), .d1(RdE1), .s(RegDstE1), .y(WriteRegE1));

	mux2 #(5) regdest2( .d0(RtE2), .d1(RdE2), .s(RegDstE2), .y(WriteRegE2));
	//mux2 #(5) jregdest( .d0(prejumpWriteRegE), .d1(5'b11111), .s(jumpE), .y(WriteRegE)); //for jal, set writereg to $ra (31)

	// muxes for forwarding from memory and writeback stages
	mux5 fwda1 ( .d0(RD1E1), .d1(ResultW1), .d2(ExecuteOutM1), .d3(ResultW2), .d4(ExecuteOutM2), .s(ForwardAE1), .y(SrcAE1));
	mux5 fwdb1 ( .d0(RD2E1), .d1(ResultW1), .d2(ExecuteOutM1), .d3(ResultW2), .d4(ExecuteOutM2), .s(ForwardBE1), .y(WriteDataE1));

	mux5 fwda2 ( .d0(RD1E2), .d1(ResultW2), .d2(ExecuteOutM2), .d3(ResultW1), .d4(ExecuteOutM1), .s(ForwardAE2), .y(SrcAE2));
	mux5 fwdb2 ( .d0(RD2E2), .d1(ResultW2), .d2(ExecuteOutM2), .d3(ResultW1), .d4(ExecuteOutM1), .s(ForwardBE2), .y(WriteDataE2));

	// alu src mux for immediate portion
	mux3 srcbmux1 ( .d0(WriteDataE1), .d1(SEimmE1), .d2(ZEimmE1), .s(ALUSrcE1), .y(SrcBE1));

	mux3 srcbmux2 ( .d0(WriteDataE2), .d1(SEimmE2), .d2(ZEimmE2), .s(ALUSrcE2), .y(SrcBE2));

	// ALU
	ALU alu1( .InA(SrcAE1), .InB(SrcBE1), .ALUControl(ALUControlE1), .out(ALUOutE1));
	ALU alu2( .InA(SrcAE2), .InB(SrcBE2), .ALUControl(ALUControlE2), .out(ALUOutE2));

	// output of execute stage
	mux2 outmux1( .d0(ALUOutE1), .d1(ZPimmE1), .s(out_selectE1), .y(ExecuteOutE1));
	mux2 outmux2( .d0(ALUOutE2), .d1(ZPimmE2), .s(out_selectE2), .y(ExecuteOutE2));

	// execute memory pipeline register
	EMReg emreg1(	.RegWriteE(RegWriteE1), .RegWriteM(RegWriteM1), .MemtoRegE(MemtoRegE1), 
			.MemtoRegM(MemtoRegM1), .MemWriteE(MemWriteE1), .MemWriteM(MemWriteM1),
			.ExecuteOutE(ExecuteOutE1), .ExecuteOutM(ExecuteOutM1), .WriteDataE(WriteDataE1), .WriteDataM(WriteDataM1), 
			.WriteRegE(WriteRegE1), .WriteRegM(WriteRegM1), .PCPlus4E(PCPlus8E1), .PCPlus4M(PCPlus8M1), .jumpE(jumpE1), 
			.jumpM(jumpM1), .En(StallM1), .Clk(CLK), .Clr(RESET));

	EMReg emreg(	.RegWriteE(RegWriteE2), .RegWriteM(RegWriteM2), .MemtoRegE(MemtoRegE2), 
			.MemtoRegM(MemtoRegM2), .MemWriteE(MemWriteE2), .MemWriteM(MemWriteM2),
			.ExecuteOutE(ExecuteOutE2), .ExecuteOutM(ExecuteOutM2), .WriteDataE(WriteDataE2), .WriteDataM(WriteDataM2), 
			.WriteRegE(WriteRegE2), .WriteRegM(WriteRegM2), .PCPlus4E(PCPlus8E2), .PCPlus4M(PCPlus8M2), .jumpE(jumpE2), 
			.jumpM(jumpM2), .En(StallM1), .Clk(CLK), .Clr(RESET)); //StallM2


//-----------------MEMORY----------------//
	
	// data memory

	ezcache cash(.addy1(ExecuteOutM1), .write_data1(WriteDataM1), .datareadmiss1(datareadmiss1), .memwrite1(MemWriteM1), .memtoreg1(MemtoRegM1), 
			.memtorege1(MemtoRegE1), .readready1(ReadReady1), .Rst(RESET), .Clk(CLK),
			.writeready1(WriteReady1), .dataout1(ReadDataM1), .datawrite1(datawrite1), 
			.address1(addymem1), .memwritethru1(memwritethru1), .readmiss1(readmiss1), 
			.addy2(ExecuteOutM2), .write_data2(WriteDataM2), .datareadmiss2(datareadmiss2), .memwrite2(MemWriteM2), .memtoreg2(MemtoRegM2), 
			.memtorege2(MemtoRegE2), .readready2(ReadReady2), 
			.writeready2(WriteReady2), .dataout2(ReadDataM2), .datawrite2(datawrite2), 
			.address2(addymem2), .memwritethru2(memwritethru2), .readmiss2(readmiss2)); 	

	data_memory dmem( .Address1(addymem1), .Read_data1(datareadmiss1), .MemWriteThrough1(memwritethru1), .Write_data1(datawrite1), .ReadMiss1(readmiss1),
			.ReadReady1(ReadReady1), .WriteReady1(WriteReady1), .Clk(CLK), .Rst(RESET),
			.Address2(addymem2), .Read_data2(datareadmiss2), .MemWriteThrough2(memwritethru2), .Write_data2(datawrite2), .ReadMiss2(readmiss2),
			.ReadReady2(ReadReady2), .WriteReady2(WriteReady2));

	// memory writeback pipeline register
	MWReg mwreg1(    .RegWriteM(RegWriteM1), .RegWriteW(RegWriteW1), .MemtoRegM(MemtoRegM1), .MemtoRegW(MemtoRegW1),
			.ReadDataM(ReadDataM1), .ReadDataW(ReadDataW1), .ExecuteOutM(ExecuteOutM1), .ExecuteOutW(ExecuteOutW1), 
			.WriteRegM(WriteRegM1), .WriteRegW(WriteRegW1), .jumpM(jumpM1), .jumpW(jumpW1), .PCPlus4M(PCPlus8M1), 
			.PCPlus4W(PCPlus8W1), .Clk(CLK), .Clr(RESET || FlushW1));	

	MWReg mwreg2(    .RegWriteM(RegWriteM2), .RegWriteW(RegWriteW2), .MemtoRegM(MemtoRegM2), .MemtoRegW(MemtoRegW2),
			.ReadDataM(ReadDataM2), .ReadDataW(ReadDataW2), .ExecuteOutM(ExecuteOutM2), .ExecuteOutW(ExecuteOutW2), 
			.WriteRegM(WriteRegM2), .WriteRegW(WriteRegW2), .jumpM(jumpM2), .jumpW(jumpW2), .PCPlus4M(PCPlus8M2), 
			.PCPlus4W(PCPlus8W2), .Clk(CLK), .Clr(RESET || FlushW1));	 //FlushW2
	
//-----------------WRITEBACK----------------//

	// muxes to determine the data to writeback to the register file
	mux2 mem2reg1( .d0(ExecuteOutW1), .d1(ReadDataW1), .s(MemtoRegW1), .y(interResultW1));
	mux2 jalmux1( .d0(interResultW1), .d1(PCPlus8W1), .s(jumpW1), .y(ResultW1));

	mux2 mem2reg2( .d0(ExecuteOutW2), .d1(ReadDataW2), .s(MemtoRegW2), .y(interResultW2));
	mux2 jalmux2( .d0(interResultW2), .d1(PCPlus8W2), .s(jumpW2), .y(ResultW2));

//---------------THORGAN HAZARD------------------//

	// hazard unit
	hazard hazard_unit(	.RsE1(RsE1), .RtE1(RtE1), .RsD1(InstrD1[25:21]), .RtD1(InstrD1[20:16]), .WriteRegE1(WriteRegE1), .WriteRegM1(WriteRegM1), .WriteRegW1(WriteRegW1),
				.RsE2(RsE2), .RtE2(RtE2), .RsD2(InstrD2[25:21]), .RtD2(InstrD2[20:16]), .WriteRegE2(WriteRegE2), .WriteRegM2(WriteRegM2), .WriteRegW2(WriteRegW2), 
				.RegWriteW1(RegWriteW1), .RegWriteM1(RegWriteM1), .MemtoRegM1(MemtoRegM1), .RegWriteE1(RegWriteE1), .MemtoRegE1(MemtoRegE1), .MemWriteM1(MemWriteM1),
				.MemWriteE1(MemWriteE1), 
				.RegWriteW2(RegWriteW2), .RegWriteM2(RegWriteM2), .MemtoRegM2(MemtoRegM2), .RegWriteE2(RegWriteE2), .MemtoRegE2(MemtoRegE2), .MemWriteM2(MemWriteM2),
				.MemWriteE2(MemWriteE2), 
				.op(InstrD1[31:26]), .funct(InstrD1[5:0]), .rst(RESET), .clk(CLK), .abort(abort), .writemiss(memwritethru1), .readmiss(readmiss1), .ireadmiss(ireadmiss1),
				.MemWriteD(MemWriteD1), .MemtoRegD(MemtoRegD1), 
				.StallF(StallF1), .StallD(StallD1), .StallE(StallE1), .StallM(StallM1), .FlushE(FlushE1), .FlushW(FlushW1), .ForwardAD1(ForwardAD1), .ForwardBD1(ForwardBD1), 
				.ForwardAE1(ForwardAE1), .ForwardBE1(ForwardBE1), .ForwardAE2(ForwardAE2), .ForwardBE2(ForwardBE2),
				.Valid(1'b0), .ReadReady(ReadReady1), .iReadReady(ireadready1), .WriteReady(WriteReady1));
	

endmodule
// EQUALITY CHECKER //
module equality (	input [5:0] op, 
			input [31:0] srca, srcb, 
			input StallD,
			output eq_ne, branch);

	// if srca == scrb and its a beq, or if srca != srcb and its a bne, eq_ne =1 , else eq_ne = 0
	
	assign eq_ne = (srca==srcb) ? ((op == 6'b000100 && StallD == 0) ? 1:0) : ((op == 6'b000101 && StallD == 0) ? 1:0);

	assign branch = (op == 6'b000100 || op == 6'b000101) ? 1:0;
endmodule

// MULTIPLEXER 2:1 //
module mux2 #(parameter WIDTH = 32)
	(input [WIDTH-1:0] d0, d1, input s, output [WIDTH-1:0] y);
	assign y = s ? d1:d0;
endmodule 

// MUX 3:1 //
module mux3 #(parameter WIDTH = 32)
	(input [WIDTH-1:0] d0, d1, d2, input [1:0] s, output [WIDTH-1:0] y); 
	assign y = s[1] ? d2:(s[0] ? d1:d0);
endmodule 

// MUX 4:1 //
module mux4 #(parameter WIDTH = 32)
	(input [WIDTH-1:0] d0, d1, d2, d3, input [1:0] s, output [WIDTH-1:0] y); 
	assign y = s[1] ? (s[0] ? d3:d2):(s[0] ? d1:d0);
endmodule 

// MUX 5:1 //
module mux5 #(parameter WIDTH = 32)
	(input [WIDTH-1:0] d0, d1, d2, d3, d4, input [2:0] s, output [WIDTH-1:0] y); 
	assign y = s[2] ? d4:(s[1] ? (s[0] ? d3:d2):(s[0] ? d1:d0));
endmodule 


// ADDER //
module adder(input [31:0] a,b, output [31:0] y);
	assign y=a+b;
endmodule

// SHIFT LEFT MULTIPLY BY 4 ////
module shftr(input [31:0] a, output [31:0] y);
	//shift left by 2 is multiplying by four
	assign y = {a[29:0], 2'b00};
endmodule

// SIGN EXTENSION //
module signext(input [15:0] a, output [31:0] y);
	assign y = {{16{a[15]}},a};
endmodule

// ZERO EXTENSION //
module zeroext(input [15:0] a, output [31:0] y);
	assign y = {{16'b0},a};			
endmodule

// ZERO PADdy //
module zeropad(input [15:0] a, output [31:0] y);
	assign y = {a,{16'b0}};
endmodule 

