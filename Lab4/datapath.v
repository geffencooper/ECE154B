module datapath (input CLK, RESET);

	// fetch and decode wires
	wire [31:0] InstrF, PCPlus8F, PCBranchD, PCInter, PCJump, PCprime, PCF, InstrD, PCPlus8D;
	wire PCSrcD, jumpD, StallF, FlushD, StallD, StallE, StallM;
	wire [31:0] liljump, PCInter2, PCPredict;
	wire ireadmiss, ireadready;
	wire [31:0] iaddy;
	wire [4095:0] idata;
	wire predictionF;
	wire [1:0] branchstate;
	
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


	// execute and memory wires1
	wire MemtoRegE1, MemWriteE1, RegDstE1, RegWriteE1, jumpE1, jumpM1, jumpW1;
	wire out_selectE1;
	wire [1:0] ALUSrcE1;
	wire [3:0] ALUControlE1;
	//wire [4:0] prejumpWriteRegE;
	wire [4:0] WriteRegE1, WriteRegM1;
	wire [1:0] ForwardAE1, ForwardBE1;
	wire [31:0] SrcAE1, SrcBE1, WriteDataE1, ALUOutE1, WriteDataM1, PCPlus8E1, PCPlus8M1, PCPlus8W1;
	wire [31:0] ExecuteOutE1;

	// execute and memory wires2
	wire MemtoRegE2, MemWriteE2, RegDstE2, RegWriteE2, jumpE2, jumpM2, jumpW2;
	wire out_selectE2;
	wire [1:0] ALUSrcE2;
	wire [3:0] ALUControlE2;
	//wire [4:0] prejumpWriteRegE;
	wire [4:0] WriteRegE2, WriteRegM2;
	wire [1:0] ForwardAE2, ForwardBE2;
	wire [31:0] SrcAE2, SrcBE2, WriteDataE2, ALUOutE2, WriteDataM2, PCPlus8E2, PCPlus8M2, PCPlus8W2;
	wire [31:0] ExecuteOutE2;

	// memory and writeback wires
	wire MemtoRegM, MemWriteM, RegWriteM;
	wire [31:0] ReadDataM, ExecuteOutW;

	wire MemtoRegW, RegWriteW;
	wire FlushW;
	wire [31:0] ReadDataW;

	wire [31:0] addymem, datawrite;
	wire [127:0] datareadmiss;
	wire ReadReady, WriteReady, readmiss, memwritethru;

//-----------------FETCH----------------//
	// PC Selection
	mux2 branchmux( .d0(PCInter2) , .d1(PCBranchD), .s((PCSrcD ^ predictionD)), .y(PCprime));
	mux2 jumpmux( .d0(PCPlus8F), .d1(PCJump), .s(jumpD), .y(PCInter));

	mux2 predictmux( .d0(PCInter), .d1(PCPredict), .s(btbhit), .y(PCInter2));

	btbuff_ btbuffer(.PC_current(PCF), .PC(PCE), .PCBranch(PCBranchE), .Branch(isBranchE), .BranchTaken(PCSrcE), .Clk(CLK), .Rst(RESET), 
		.statein(branchstate), .PCPredict(PCPredict), .prediction(predictionF), .btbhit(btbhit)); //PCPredict is output to the new mux


        // pc register and instruction memory
	register #(32) PCreg( .D(PCprime), .Q(PCF), .En(StallF), .Clk(CLK), .Clr(RESET));
	
	assign abort = PCSrcD ^ predictionD;

	icache instr_cache(.addy(PCF), .datareadmiss(idata),. readready(ireadready), 
			   .Rst(RESET), .Clk(CLK), .abort(abort),
			   .data(InstrF), .address(iaddy), .readmiss(ireadmiss));

	inst_memory #(33) imem( .Address(iaddy), .Read_data(idata), .ReadReady(ireadready), .ReadMiss(ireadmiss), 
				.abort(abort), .Clk(CLK), .Rst(RESET));
	adder plus4( .a(PCF), .b(32'b100), .y(PCPlus8F));

        // flush fetch stage when have a jump instruction or we incorrectly guessed the branch result (prediction and ground truth should both be 0 or 1)
	assign FlushD = jumpD || (PCSrcD^predictionD);

	// Fetch-Decode pipeline register, clear on a flush or reset
	FDReg fdreg( .InstrF(InstrF), .InstrD(InstrD), .PCPlus4F(PCPlus8F), .PCPlus4D(PCPlus8D), .PCF(PCF), .PCD(PCD), 
			.predictionF(predictionF), .predictionD(predictionD), .En(StallD), .Clk(CLK), .Clr(FlushD || RESET));
	
        //jump target addy
	shftr jumpshift( .a({6'b0,InstrD[25:0]}), .y(liljump));
	assign PCJump = {PCPlus8F[31:28],liljump[27:0]};

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
			.ZPimmD(ZPimmD2), .ZPimmE(ZPimmE2), .PCPlus4D(PCPlus8D2), .PCPlus4E(PCPlus8E2), .Clk(CLK), .Clr(FlushE2 || RESET), .En(StallE2),
			.PCE(PCE2), .PCD(PCD2), .isBranchE(isBranchE2), .isBranchD(isBranchD2), .PCSrcE(PCSrcE2), .PCSrcD(PCSrcD2), .PCBranchE(PCBranchE2), .PCBranchD(PCBranchD2));

//-----------------EXECUTE----------------//

	bht_ ranch_predictor(.PC(PCE), .Branch(isBranchE), .BranchTaken(PCSrcE), .Clk(CLK), .Rst(RESET), .stateout(branchstate));

	// muxes for determining the destination register
	mux2 #(5) regdest( .d0(RtE), .d1(RdE), .s(RegDstE), .y(WriteRegE));
	//mux2 #(5) jregdest( .d0(prejumpWriteRegE), .d1(5'b11111), .s(jumpE), .y(WriteRegE)); //for jal, set writereg to $ra (31)

	// muxes for forwarding from memory and writeback stages
	mux3 fwda ( .d0(RD1E), .d1(ResultW), .d2(ExecuteOutM), .s(ForwardAE), .y(SrcAE));
	mux3 fwdb ( .d0(RD2E), .d1(ResultW), .d2(ExecuteOutM), .s(ForwardBE), .y(WriteDataE));

	// alu src mux for immediate portion
	mux3 srcbmux ( .d0(WriteDataE), .d1(SEimmE), .d2(ZEimmE), .s(ALUSrcE), .y(SrcBE));

	// ALU
	ALU alu( .InA(SrcAE), .InB(SrcBE), .ALUControl(ALUControlE), .out(ALUOutE));

	// output of execute stage
	mux2 outmux( .d0(ALUOutE), .d1(ZPimmE), .s(out_selectE), .y(ExecuteOutE));

	// execute memory pipeline register
	EMReg emreg(	.RegWriteE(RegWriteE), .RegWriteM(RegWriteM), .MemtoRegE(MemtoRegE), 
			.MemtoRegM(MemtoRegM), .MemWriteE(MemWriteE), .MemWriteM(MemWriteM),
			.ExecuteOutE(ExecuteOutE), .ExecuteOutM(ExecuteOutM), .WriteDataE(WriteDataE), .WriteDataM(WriteDataM), 
			.WriteRegE(WriteRegE), .WriteRegM(WriteRegM), .PCPlus4E(PCPlus8E), .PCPlus4M(PCPlus8M), .jumpE(jumpE), .jumpM(jumpM), .En(StallM), .Clk(CLK), .Clr(RESET));

//-----------------MEMORY----------------//
	
	// data memory

	ezcache cash(.addy(ExecuteOutM), .write_data(WriteDataM), .datareadmiss(datareadmiss), .memwrite(MemWriteM), .memtoreg(MemtoRegM), .memtorege(MemtoRegE), .readready(ReadReady), .Rst(RESET), .Clk(CLK),
			.writeready(WriteReady), .data(ReadDataM), .datawrite(datawrite), .address(addymem), .memwritethru(memwritethru), .readmiss(readmiss)); 	

	data_memory dmem( .Address(addymem), .Read_data(datareadmiss), .MemWriteThrough(memwritethru), .Write_data(datawrite), .ReadMiss(readmiss), .ReadReady(ReadReady),
			  .WriteReady(WriteReady), .Clk(CLK), .Rst(RESET));

	// memory writeback pipeline register
	MWReg mwreg(    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW), .MemtoRegM(MemtoRegM), .MemtoRegW(MemtoRegW),
			.ReadDataM(ReadDataM), .ReadDataW(ReadDataW), .ExecuteOutM(ExecuteOutM), .ExecuteOutW(ExecuteOutW), 
			.WriteRegM(WriteRegM), .WriteRegW(WriteRegW), .jumpM(jumpM), .jumpW(jumpW), .PCPlus4M(PCPlus8M), .PCPlus4W(PCPlus8W), .Clk(CLK), .Clr(RESET || FlushW));	
	
//-----------------WRITEBACK----------------//

	// muxes to determine the data to writeback to the register file
	mux2 mem2reg( .d0(ExecuteOutW), .d1(ReadDataW), .s(MemtoRegW), .y(interResultW));
	mux2 jalmux( .d0(interResultW), .d1(PCPlus8W), .s(jumpW), .y(ResultW));

//---------------THORGAN HAZARD------------------//

	// hazard unit
	hazard hazard_unit(	.RsE(RsE), .RtE(RtE), .RsD(InstrD[25:21]), .RtD(InstrD[20:16]), .WriteRegE(WriteRegE), .WriteRegM(WriteRegM), .WriteRegW(WriteRegW), 
				.RegWriteW(RegWriteW), .RegWriteM(RegWriteM), .MemtoRegM(MemtoRegM), .RegWriteE(RegWriteE), .MemtoRegE(MemtoRegE), .MemWriteM(MemWriteM),
				.MemWriteE(MemWriteE), 
				.op(InstrD[31:26]), .funct(InstrD[5:0]), .rst(RESET), .clk(CLK), .abort(abort), .writemiss(memwritethru), .readmiss(readmiss), .ireadmiss(ireadmiss),
				.MemWriteD(MemWriteD), .MemtoRegD(MemtoRegD), 
				.StallF(StallF), .StallD(StallD), .StallE(StallE), .StallM(StallM), .FlushE(FlushE), .FlushW(FlushW), .ForwardAD(ForwardAD), .ForwardBD(ForwardBD), 
				.ForwardAE(ForwardAE), .ForwardBE(ForwardBE), .Valid(Valid), .ReadReady(ReadReady), .iReadReady(ireadready), .WriteReady(WriteReady));
	

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

