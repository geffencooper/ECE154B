module datapath (input CLK, RESET);

	// fetch and decode wires
	wire [31:0] InstrF, PCPlus4F, PCBranchD, PCInter, PCJump, PCprime, PCF, InstrD, PCPlus4D;
	wire PCSrcD, jumpD, StallF, FlushD, StallD, StallE, StallM;
	wire [31:0] liljump, PCInter2, PCPredict;
	wire ireadmiss, ireadready;
	wire [31:0] iaddy;
	wire [4095:0] idata;
	wire predictionF;
	wire [1:0] branchstate;
	
	// decode and execute wires
	wire MemtoRegD, MemWriteD, RegDstD, RegWriteD, start_multD, mult_signD;
	wire [1:0] out_selectD, ALUSrcD;
	wire [3:0] ALUControlD;
	wire [31:0] RD1D, RD2D, ResultW, interResultW;
	wire [4:0] WriteRegW;
	wire [31:0] SEimmD, ZEimmD, ZPimmD, SEimmshftD, SEimmE, ZEimmE, ZPimmE;
	wire [31:0] ExecuteOutM, branch_checkA, branch_checkB;
	wire ForwardAD, ForwardBD;
	wire [31:0] RD1E, RD2E; 
	wire [4:0] RsE, RtE, RdE;
	wire FlushE, btbhit;
	wire isBranchD, isBranchE, predictionD, PCSrcE;
	wire [31:0] PCE, PCD, PCBranchE;

	// execute and memory wires
	wire MemtoRegE, MemWriteE, RegDstE, RegWriteE, start_multE, mult_signE, jumpE, jumpM, jumpW;
	wire [1:0] out_selectE, ALUSrcE;
	wire [3:0] ALUControlE;
	wire [4:0] prejumpWriteRegE, WriteRegE, WriteRegM;
	wire [1:0] ForwardAE, ForwardBE;
	wire [31:0] SrcAE, SrcBE, WriteDataE, ALUOutE, WriteDataM, PCPlus4E, PCPlus4M, PCPlus4W;
	wire [63:0] Product;
	wire [63:0] ProdOut;
	wire Valid;
	wire [31:0] ExecuteOutE;

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
	mux2 branchmux( .d0(PCPlus4F) , .d1(PCBranchD), .s((PCSrcD ^ predictionD)), .y(PCInter));
	mux2 jumpmux( .d0(PCInter), .d1(PCJump), .s(jumpD), .y(PCInter2));

	mux2 predictmux( .d0(PCInter2), .d1(PCPredict), .s(btbhit), .y(PCprime));

	btbuff btbuffer(.PC_current(PCF), .PC(PCE), .PCBranch(PCBranchE), .Branch(isBranchE), .BranchTaken(PCSrcE), .Clk(CLK), .Rst(RESET), 
		.statein(branchstate), .PCPredict(PCPredict), .prediction(predictionF), .btbhit(btbhit)); //PCPredict is output to the new mux


        // pc register and instruction memory
	register #(32) PCreg( .D(PCprime), .Q(PCF), .En(StallF), .Clk(CLK), .Clr(RESET));

	icache instr_cache(.addy(PCF), .datareadmiss(idata),. readready(ireadready), 
			   .Rst(RESET), .Clk(CLK),
			   .data(InstrF), .address(iaddy), .readmiss(ireadmiss));

	inst_memory #(42) imem( .Address(iaddy), .Read_data(idata), .ReadReady(ireadready), .ReadMiss(ireadmiss), 
				.abort(1'b0), .Clk(CLK), .Rst(RESET));
	adder plus4( .a(PCF), .b(32'b100), .y(PCPlus4F));

        // flush fetch stage when have a jump instruction or we incorrectly guessed the branch result (prediction and ground truth should both be 0 or 1)
	assign FlushD = jumpD || (PCSrcD^predictionD);

	// Fetch-Decode pipeline register, clear on a flush or reset
	FDReg fdreg( .InstrF(InstrF), .InstrD(InstrD), .PCPlus4F(PCPlus4F), .PCPlus4D(PCPlus4D), .PCF(PCF), .PCD(PCD), 
			.predictionF(predictionF), .predictionD(predictionD), .En(StallD), .Clk(CLK), .Clr(FlushD || RESET));
	
        //jump target addy
	shftr jumpshift( .a({6'b0,InstrD[25:0]}), .y(liljump));
	assign PCJump = {PCPlus4F[31:28],liljump[27:0]};

//-----------------DECODE----------------//
	
	// control logic
	controller ctrlr(	.op(InstrD[31:26]), .funct(InstrD[5:0]), .memtoreg(MemtoRegD), .memwrite(MemWriteD), .alusrc(ALUSrcD), .out_select(out_selectD), 
				.regdst(RegDstD), .regwrite(RegWriteD), .start_mult(start_multD), .mult_sign(mult_signD), .jump(jumpD), .alucontrol(ALUControlD));

	// register file
	reg_file regfile( .A1(InstrD[25:21]), .A2(InstrD[20:16]), .RD1(RD1D), .RD2(RD2D), .WR(WriteRegW), .WD(ResultW), .Write_enable(RegWriteW), .Rst(RESET), .Clk(CLK));
	
	//immediate handling
	signext signextend( .a(InstrD[15:0]), .y(SEimmD));
	zeroext zeroextend( .a(InstrD[15:0]), .y(ZEimmD));
	zeropad zeropadder( .a(InstrD[15:0]), .y(ZPimmD));
	
	// handle branch target address
	shftr branchshift( .a(SEimmD), .y(SEimmshftD));
	adder btadder( .a(SEimmshftD), .b(PCPlus4D), .y(PCBranchD));
	
	// muxes for branch conditions to get most up to date registers
	mux2 branchfwda( .d0(RD1D), .d1(ExecuteOutM), .s(ForwardAD), .y(branch_checkA));
	mux2 branchfwdb( .d0(RD2D), .d1(ExecuteOutM), .s(ForwardBD), .y(branch_checkB));

	// branch comparator
	equality eq( .op(InstrD[31:26]), .srca(branch_checkA), .srcb(branch_checkB), .StallD(StallD), .eq_ne(PCSrcD), .branch(isBranchD));
	
	// decode execute pipeline register, clear on a flush or reset
	DEReg dereg( 	.RegWriteD(RegWriteD), .RegWriteE(RegWriteE), .MemtoRegD(MemtoRegD), .MemtoRegE(MemtoRegE), .MemWriteD(MemWriteD), 
			.MemWriteE(MemWriteE), .ALUControlD(ALUControlD), .ALUControlE(ALUControlE), .ALUSrcD(ALUSrcD), .ALUSrcE(ALUSrcE), 
			.RegDstD(RegDstD), .RegDstE(RegDstE), .StartMultD(start_multD), .StartMultE(start_multE), .MultSignD(mult_signD), 
			.MultSignE(mult_signE), .OutSelectD(out_selectD), .OutSelectE(out_selectE), .jumpD(jumpD), .jumpE(jumpE),
			.Rd1D(RD1D), .Rd2D(RD2D), .Rd1E(RD1E), .Rd2E(RD2E), .RsD(InstrD[25:21]), .RsE(RsE), .RtD(InstrD[20:16]), 
			.RtE(RtE), .RdD(InstrD[15:11]), . RdE(RdE), .SEimmD(SEimmD), .SEimmE(SEimmE), .ZEimmD(ZEimmD), .ZEimmE(ZEimmE),
			.ZPimmD(ZPimmD), .ZPimmE(ZPimmE), .PCPlus4D(PCPlus4D), .PCPlus4E(PCPlus4E), .Clk(CLK), .Clr(FlushE || RESET), .En(StallE),
			.PCE(PCE), .PCD(PCD), .isBranchE(isBranchE), .isBranchD(isBranchD), .PCSrcE(PCSrcE), .PCSrcD(PCSrcD), .PCBranchE(PCBranchE), .PCBranchD(PCBranchD));

//-----------------EXECUTE----------------//

	bht bhtable(.PC(PCE), .Branch(isBranchE), .BranchTaken(PCSrcE), .Clk(CLK), .Rst(RESET), .stateout(branchstate));

	// muxes for determining the destination register
	mux2 #(5) regdest( .d0(RtE), .d1(RdE), .s(RegDstE), .y(prejumpWriteRegE));
	mux2 #(5) jregdest( .d0(prejumpWriteRegE), .d1(5'b11111), .s(jumpE), .y(WriteRegE)); //for jal, set writereg to $ra (31)

	// muxes for forwarding from memory and writeback stages
	mux3 fwda ( .d0(RD1E), .d1(ResultW), .d2(ExecuteOutM), .s(ForwardAE), .y(SrcAE));
	mux3 fwdb ( .d0(RD2E), .d1(ResultW), .d2(ExecuteOutM), .s(ForwardBE), .y(WriteDataE));

	// alu src mux for immediate portion
	mux3 srcbmux ( .d0(WriteDataE), .d1(SEimmE), .d2(ZEimmE), .s(ALUSrcE), .y(SrcBE));

	// ALU and multiplier (multiplier gets cleared on a reset or when next mult comes in)
	ALU alu( .InA(SrcAE), .InB(SrcBE), .ALUControl(ALUControlE), .out(ALUOutE));
	mult multiplier( 	.SrcA(SrcAE), .SrcB(SrcBE), .Prod(Product), .ProdV(Valid), .MultStart(start_multE), .MultSign(mult_signE), 
				.Clk(CLK), .Rst(start_multD || RESET)); // reset is start_multD so that mult is reset one cycle before used agian
	register #(64) multreg( .D(Product), .Q(ProdOut), .En(~Valid), .Clk(CLK), .Clr(RESET));

	// output of execute stage
	mux4 outmux( .d0(ALUOutE), .d1(ZPimmE), .d2(ProdOut[63:32]), .d3(ProdOut[31:0]), .s(out_selectE), .y(ExecuteOutE));

	// execute memory pipeline register
	EMReg emreg(	.RegWriteE(RegWriteE), .RegWriteM(RegWriteM), .MemtoRegE(MemtoRegE), 
			.MemtoRegM(MemtoRegM), .MemWriteE(MemWriteE), .MemWriteM(MemWriteM),
			.ExecuteOutE(ExecuteOutE), .ExecuteOutM(ExecuteOutM), .WriteDataE(WriteDataE), .WriteDataM(WriteDataM), 
			.WriteRegE(WriteRegE), .WriteRegM(WriteRegM), .PCPlus4E(PCPlus4E), .PCPlus4M(PCPlus4M), .jumpE(jumpE), .jumpM(jumpM), .En(StallM), .Clk(CLK), .Clr(RESET));

//-----------------MEMORY----------------//
	
	// data memory

	ezcache cash(.addy(ExecuteOutM), .write_data(WriteDataM), .datareadmiss(datareadmiss), .memwrite(MemWriteM), .memtoreg(MemtoRegM), .memtorege(MemtoRegE), .readready(ReadReady), .Rst(RESET), .Clk(CLK),
			.writeready(WriteReady), .data(ReadDataM), .datawrite(datawrite), .address(addymem), .memwritethru(memwritethru), .readmiss(readmiss)); 	

	data_memory dmem( .Address(addymem), .Read_data(datareadmiss), .MemWriteThrough(memwritethru), .Write_data(datawrite), .ReadMiss(readmiss), .ReadReady(ReadReady),
			  .WriteReady(WriteReady), .Clk(CLK), .Rst(RESET));

	// memory writeback pipeline register
	MWReg mwreg(    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW), .MemtoRegM(MemtoRegM), .MemtoRegW(MemtoRegW),
			.ReadDataM(ReadDataM), .ReadDataW(ReadDataW), .ExecuteOutM(ExecuteOutM), .ExecuteOutW(ExecuteOutW), 
			.WriteRegM(WriteRegM), .WriteRegW(WriteRegW), .jumpM(jumpM), .jumpW(jumpW), .PCPlus4M(PCPlus4M), .PCPlus4W(PCPlus4W), .Clk(CLK), .Clr(RESET || FlushW));	
	
//-----------------WRITEBACK----------------//

	// muxes to determine the data to writeback to the register file
	mux2 mem2reg( .d0(ExecuteOutW), .d1(ReadDataW), .s(MemtoRegW), .y(interResultW));
	mux2 jalmux( .d0(interResultW), .d1(PCPlus4W), .s(jumpW), .y(ResultW));

//---------------THORGAN HAZARD------------------//

	// hazard unit
	hazard hazard_unit(	.RsE(RsE), .RtE(RtE), .RsD(InstrD[25:21]), .RtD(InstrD[20:16]), .WriteRegE(WriteRegE), .WriteRegM(WriteRegM), .WriteRegW(WriteRegW), 
				.RegWriteW(RegWriteW), .RegWriteM(RegWriteM), .MemtoRegM(MemtoRegM), .RegWriteE(RegWriteE), .MemtoRegE(MemtoRegE), .MemWriteM(MemWriteM),
				.MemWriteE(MemWriteE), 
				.op(InstrD[31:26]), .funct(InstrD[5:0]), .rst(RESET), .clk(CLK), .writemiss(memwritethru), .readmiss(readmiss), .ireadmiss(ireadmiss),
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

