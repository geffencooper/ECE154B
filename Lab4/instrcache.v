module icache 
#(parameter ROWS = 32'h00000001) //1 rows
(input [31:0] addy1, 
 input [31:0] addy2,
 input [4095:0] datareadmiss, 
 input readready, Rst, Clk, abort,
 output reg [31:0] instr1,
 output reg [31:0] instr2, 
 output reg [31:0] address1, 
 output reg readmiss);

reg [2:0] state;

// states
	parameter INIT  = 3'b000, // initial, wait for start signal
	READ = 3'b001; // if memtoreg == 1, and a miss

	reg [31:0] address2;

	wire [31:0] datai1;
	wire [31:0] datai2;

	wire [23:0] tagin1;
	wire [23:0] tagin2;

	wire [7:0] blk_offset1;
	wire [7:0] blk_offset2

	reg abortion;

	reg [31:0] addymem1;   //stored in internal reg
	reg [31:0] addymem2;
	
	assign tagin1 = address1[31:9];
	assign blk_offset1 = address1[8:2]; //block size 128

	assign tagin2 = address2[31:9];
	assign blk_offset2 = address2[8:2]; //block size 128


	reg [4119:0] way1; //update number of bits
	
	wire v1, eq1, hit1,eq2,hit2;
	wire [4095:0] data1, databus1,databus2;
	wire [255:0] middata1,middata2;
	wire [17:0] tag1;

	assign v1 = way1[4119];
	assign tag1 = way1[4118:4096];
	assign data1 = way1[4095:0];

	assign eq1 = (tag1==tagin1);
	assign hit1 = (v1&&eq1);//||Rst;
	assign eq2 = (tag1==tagin2);
	assign hit2 = (v1&&eq2);//||Rst;

	bufferz buf1(.enable(hit1), .datasrc(data1), .databus(databus1));
	bufferz buf2(.enable(hit2), .datasrc(data1), .databus(databus2));
	
	mux16 mux16s1(.d0(databus1[255:0]), .d1(databus1[511:256]), .d2(databus1[767:512]), .d3(databus1[1023:768]), 
		     .d4(databus1[1279:1024]), .d5(databus1[1535:1280]), .d6(databus1[1791:1536]), .d7(databus1[2047:1792]), 
		     .d8(databus1[2303:2048]), .d9(databus1[2559:2304]), .d10(databus1[2815:2560]), .d11(databus1[3071:2816]), 
		     .d12(databus1[3327:3072]), .d13(databus1[3583:3328]), .d14(databus1[3839:3584]), .d15(databus1[4095:3840]),
		     .s(blk_offset1[6:3]), .y(middata1));

	mux8 mux8s1(.d0(middata1[31:0]), .d1(middata1[63:32]), .d2(middata1[95:64]), .d3(middata1[127:96]), 
		   .d4(middata1[159:128]), .d5(middata1[191:160]), .d6(middata1[223:192]), .d7(middata1[255:224]), 
		   .s(blk_offset1[2:0]), .y(datai1));

	mux16 mux16s2(.d0(databus2[255:0]), .d1(databus2[511:256]), .d2(databus2[767:512]), .d3(databus2[1023:768]), 
		     .d4(databus2[1279:1024]), .d5(databus2[1535:1280]), .d6(databus2[1791:1536]), .d7(databus2[2047:1792]), 
		     .d8(databus2[2303:2048]), .d9(databus2[2559:2304]), .d10(databus2[2815:2560]), .d11(databus2[3071:2816]), 
		     .d12(databus2[3327:3072]), .d13(databus2[3583:3328]), .d14(databus2[3839:3584]), .d15(databus2[4095:3840]),
		     .s(blk_offset2[6:3]), .y(middata2));

	mux8 mux8s2(.d0(middata2[31:0]), .d1(middata2[63:32]), .d2(middata2[95:64]), .d3(middata2[127:96]), 
		   .d4(middata2[159:128]), .d5(middata2[191:160]), .d6(middata2[223:192]), .d7(middata2[255:224]), 
		   .s(blk_offset2[2:0]), .y(datai2));

	integer i;
	always @(posedge Rst)
	begin
		state <= INIT; //ad other things on reset
		readmiss <= 0;
	 	data1 <= 32'b0;
		addymem1 <= 32'b0;
		address1 <= 32'b0;
		way1 <= 4120'b0; //update number of bits
		data2 <= 32'b0;
		addymem2 <= 32'b0;
		address2 <= 32'b0;
		way2 <= 4120'b0; //update number of bits
		abortion <= 0;
	end
	


	always @(posedge readready, posedge Clk, hit1, addy1, datai1, posedge abort,negedge Rst) //added posedge write_word
	begin
   		case(state)
		INIT: begin
			if (~Rst)
			begin
				abortion <= abort;
			end
			if (readready || abortion)
			begin
				readmiss<=0;
			end
			if (~Rst)
			begin
				//$display("addy: %d, clock: %d, hit1: %d, abort: %d",addy,Clk,hit1, abort);
				//write_word <= write_data; //if you want to write, store that data and address in case of a miss
				address1 <= addy1;
				address2 <= addy2;
				if (hit1)
				begin
					instr1 <= datai1;
					readmiss <= 0;
					if (hit2)
					begin
						instr2 <= datai2;
						readmiss <= 0;
					end
				end
				else if (~hit1&&~abortion)
				begin
					//$display("--addy: %d, clock: %d, hit1: %d",addy,Clk,hit1);
					readmiss <= 1;
					addymem1 <= address1;
					state <= READ;
				end
			end
		end
		READ: begin
			if(readready == 1) 
			begin
				way1[4095:0] = datareadmiss;
				way1[4118:4096] = tagin1;
				way1[4119] = 1;
				instr1 = datai1;
				readmiss = 0;
				state = INIT;
			end
			else if (abortion)
			begin
				abortion = 0;
				state = INIT;
			end
		end
		endcase
	end

endmodule

// MUX 8:1 //
module mux8 #(parameter WIDTH = 32)
	(input [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7, input [2:0] s, output [WIDTH-1:0] y); 
	assign y = s[2] ? (s[1] ? (s[0] ? d7:d6):(s[0] ? d5:d4)):(s[1] ? (s[0] ? d3:d2):(s[0] ? d1:d0));
endmodule 

// MUX 16:1 //
module mux16 #(parameter WIDTH = 256)
	(input [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, input [3:0] s, output [WIDTH-1:0] y); 
	assign y = s[3] ? (s[2] ? (s[1] ? (s[0] ? d15:d14):(s[0] ? d13:d12)):(s[1] ? (s[0] ? d11:d10):(s[0] ? d9:d8))):(s[2] ? (s[1] ? (s[0] ? d7:d6):(s[0] ? d5:d4)):(s[1] ? (s[0] ? d3:d2):(s[0] ? d1:d0)));
endmodule 


module bufferz (input enable, input [4095:0] datasrc, output [4095:0] databus);

	assign databus = enable ? datasrc:4096'h0000; //update bit numbers

endmodule
