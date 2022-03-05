module controller(input   [5:0] op, funct,
                  output        memtoreg, memwrite,
		  output  [1:0] alusrc,   //out_select is our version of WBsrc 
                  output        out_select, regdst, regwrite,
                  output        jump,
                  output  [3:0] alucontrol);


	wire [1:0] aluop;

	maindec md(op, funct, memtoreg, memwrite, alusrc,
			regdst, regwrite, jump, aluop, out_select); 

	aludec ad(funct, op, aluop, alucontrol);

endmodule

module maindec(	input	[5:0] op, funct,
		output	memtoreg, memwrite, 
		output  [1:0] alusrc, 
		output	regdst, regwrite,
		output	jump,
		output	[1:0] aluop,
		output	out_select); 

	reg [9:0] controls; 
	
	assign {regwrite, regdst, alusrc, memwrite,
		memtoreg, jump, aluop,
		out_select} = controls; 

	always @ * begin
		case(op) //n for output_branch
			6'b000000: controls <= 10'b1100000100; //Rtype
			6'b100011: controls <= 10'b1001010000; //lw
			6'b101011: controls <= 10'b0001100000; //sw
			6'b000100: controls <= 10'b0000000000; //beq
			6'b000101: controls <= 10'b0000000000; //bne
			6'b001000: controls <= 10'b1001000000; //addi
			6'b001100: controls <= 10'b1010000110; //andi
			6'b001101: controls <= 10'b1010000110; //ori
			6'b111100: controls <= 10'b1010000110; //xori 
			6'b000010: controls <= 10'b1000001000; //j
			6'b001010: controls <= 10'b1001000110; //slti
			6'b001111: controls <= 10'b1011000000; //lui
			default: controls <= 13'b0000000000;
		endcase
	end
			
endmodule

module aludec(	input	[5:0] funct, op,
		input	[1:0] aluop,
		output	reg [3:0] alucontrol);

	always @ * begin
		case(aluop)
			2'b00: alucontrol <= 4'b0010; //add
			2'b01: alucontrol <= 4'b1010; //subtract
			2'b11: case(op) //I-type Logical Instructions
				6'b001100: alucontrol <= 4'b0000; //andi
				6'b001101: alucontrol <= 4'b0001; //ori
				6'b111100: alucontrol <= 4'b0100; //xori
				6'b001010: alucontrol <= 4'b1011; //slti
			endcase
			default: case(funct) // if aluop is 10 (which means R type), look at funct field
				6'b100000: alucontrol <= 4'b0010; //add
				6'b100010: alucontrol <= 4'b1010; //sub
				6'b100100: alucontrol <= 4'b0000; //and
				6'b100101: alucontrol <= 4'b0001; //or
				6'b101010: alucontrol <= 4'b1011; //slt
				6'b111111: alucontrol <= 4'b0100; //xor
				6'b111110: alucontrol <= 4'b1100; //xnor
				default: alucontrol <= 4'b0000;
			endcase
		endcase
	end

endmodule
