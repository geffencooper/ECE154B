module icache 
#(parameter ROWS = 32'h00000001) //1 rows
(input [31:0] addy, 
 input [4095:0] datareadmiss, 
 input readready, Rst, Clk, abort,
 output reg [31:0] data, 
 output reg [31:0] address, 
 output reg readmiss);

reg [2:0] state;

// states
	parameter INIT  = 3'b000, // initial, wait for start signal
	READ = 3'b001; // if memtoreg == 1, and a miss

	wire [31:0] datai;

	wire [23:0] tag;
	wire [7:0] blk_offset;

	reg abortion;

	reg [31:0] addymem;   //stored in internal reg
	
	assign tag = address[31:9];
	assign blk_offset = address[8:2]; //block size 128


	reg [4119:0] way1; //update number of bits
	
	wire v1, eq1, hit1;
	wire [4095:0] data1, databus1;
	wire [255:0] middata;
	wire [17:0] tag1;

	assign v1 = way1[4119];
	assign tag1 = way1[4118:4096];
	assign data1 = way1[4095:0];

	assign eq1 = (tag1==tag);
	assign hit1 = (v1&&eq1);//||Rst;

	bufferz buf1(.enable(hit1), .datasrc(data1), .databus(databus1));
	
	mux16 mux16s(.d0(databus1[255:0]), .d1(databus1[511:256]), .d2(databus1[767:512]), .d3(databus1[1023:768]), 
		     .d4(databus1[1279:1024]), .d5(databus1[1535:1280]), .d6(databus1[1791:1536]), .d7(databus1[2047:1792]), 
		     .d8(databus1[2303:2048]), .d9(databus1[2559:2304]), .d10(databus1[2815:2560]), .d11(databus1[3071:2816]), 
		     .d12(databus1[3327:3072]), .d13(databus1[3583:3328]), .d14(databus1[3839:3584]), .d15(databus1[4095:3840]),
		     .s(blk_offset[6:3]), .y(middata));

	mux8 mux8s(.d0(middata[31:0]), .d1(middata[63:32]), .d2(middata[95:64]), .d3(middata[127:96]), 
		   .d4(middata[159:128]), .d5(middata[191:160]), .d6(middata[223:192]), .d7(middata[255:224]), 
		   .s(blk_offset[2:0]), .y(datai));

	integer i;
	always @(posedge Rst)
	begin
		state <= INIT; //ad other things on reset
		readmiss <= 0;
	 	data <= 32'b0;
		addymem <= 32'b0;
		address <= 32'b0;
		way1 <= 4120'b0; //update number of bits
		abortion <= 0;
	end
	


	always @(posedge readready, posedge Clk, hit1, addy, datai, posedge abort,negedge Rst) //added posedge write_word
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
				address <= addy;
				if (hit1)
				begin
					data <= datai;
					readmiss <= 0;
				end
				else if (~hit1&&~abortion)
				begin
					//$display("--addy: %d, clock: %d, hit1: %d",addy,Clk,hit1);
					readmiss <= 1;
					addymem <= address;
					state <= READ;
				end
			end
		end
		READ: begin
			if(readready == 1) 
			begin
				way1[4095:0] = datareadmiss;
				way1[4118:4096] = tag;
				way1[4119] = 1;
				data = datai;
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
