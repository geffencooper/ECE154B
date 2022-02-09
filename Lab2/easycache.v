module ezcache 
#(parameter ROWS = 32'h00000040) //1024 rows
(input [31:0] addy, write_data, 
 input [127:0] datareadmiss, 
 input memwrite, memtoreg, readready, Rst, Clk, writeready,
 output reg [31:0] data, datawrite, address, //changed from addymem -> address (and in datapath)
 output reg memwritethru, readmiss);

reg [2:0] state;

// states
	parameter INIT  = 3'b000, // initial, wait for start signal
	READ = 3'b001, // if memtoreg == 1, and a miss
	WRITEhit = 3'b010, // if signed, first make numbers positive
	WRITEmiss = 3'b011; // do the multiplication

	wire [21:0] tag;
	wire [6:0] set;
	wire [1:0] blk_offset;

	reg [31:0] write_word; //stored in internal reg
	reg [31:0] addymem;   //stored in internal reg
	
	assign tag = address[31:10];  //18 bit tag
	assign set = address[9:4];  //
	assign blk_offset = address[3:2]; //block size 4


	reg [150:0] way1[0:ROWS-1];  //0
	reg [150:0] way2[0:ROWS-1];  //1
	reg lru[0:ROWS-1];
	
	wire v1, v2, eq1, eq2, hit1, hit2;
	wire [127:0] data1, data2, databus, databus1, databus2;
	wire [22:0] tag1, tag2;
	wire [31:0] outmux;

	assign v1 = way1[set][150];
	assign tag1 = way1[set][149:128];
	assign data1 = way1[set][127:0];

	assign eq1 = (tag1==tag);
	assign hit1 = v1&&eq1;

	buffer buf1(.enable(hit1), .datasrc(data1), .databus(databus1));
	
	assign v2 = way2[set][150];
	assign tag2 = way2[set][149:128];
	assign data2 = way2[set][127:0];

	assign eq2 = (tag2==tag);
	assign hit2 = v2&&eq2;

	buffer buf2(.enable(hit2), .datasrc(data2), .databus(databus2));
	
	assign databus = databus1 | databus2;
	mux4 blk_select(.d0(databus[31:0]), .d1(databus[63:32]), .d2(databus[95:64]), .d3(databus[127:96]), .s(blk_offset), .y(outmux));

	assign hit = hit1||hit2;
	integer i;
	always @(posedge Rst)
	begin
		state <= INIT; //ad other things on reset
		memwritethru <= 0;
		readmiss <= 0;
	 	data <= 32'b0;
		datawrite <= 32'b0;
		addymem <= 32'b0;
		address <= 32'b0;
		write_word <= 32'b0;
		for (i=0;i<ROWS;i=i+1)
		begin
			way1[i] <= 151'b0;
			way2[i] <= 151'b0;
			lru[i] <= 0;
		end

	end
	


	always @(posedge memwrite, posedge readready, posedge writeready, posedge Clk) //added posedge write_word
	begin
   		case(state)
		INIT: begin
			if (readready)
			begin
				readmiss<=0;
			end
			if ((memwrite || memtoreg) && ~Rst)
			begin
				//write_word <= write_data; //if you want to write, store that data and address in case of a miss
				address <= addy;
				write_word <= write_data; //write_word -> datawrite
				datawrite <= write_data;
				if (memtoreg && hit)
				begin
					data <= outmux;
					readmiss <= 0;
					memwritethru <= 0;
					if(hit1)
					begin
						lru[set] <= 1;
					end
					else
					begin
						lru[set] <=0;
					end
				end
				else if (memtoreg && ~hit)
				begin
					readmiss <= 1;
					memwritethru <= 0;
					addymem <= address;
					state <= READ;
				end
				else if (memwrite && hit)
				begin
					//datawrite <= write_word;  //write through cache, so also write it to memory
					addymem <= address;
					memwritethru <= 1;
					readmiss <=0;
					state <= WRITEhit;
				end
				else if (memwrite && ~hit)
				begin
					//datawrite <= write_word;  //write through cache, so also write it to memory
					addymem <= address;
					memwritethru <= 1;
					readmiss <=1;
					state <= WRITEmiss;
				end
			end
		end
		WRITEmiss: begin
			if(readready == 1) //how to wait for this
			begin
				if(lru[set])
				begin
					way2[set][127:0] = datareadmiss;
					way2[set][149:128] = tag;
					case(blk_offset)//make sure the word is put in correct spot in the block
	        				2'b00: way2[set][31:0] = write_word;
						2'b01: way2[set][63:32] = write_word;
	        				2'b10: way2[set][95:64] = write_word;
	        				2'b11: way2[set][127:96] = write_word;
					endcase
					way2[set][149:128] = tag;
					way2[set][150] = 1;
					lru[set] = 0; //way 1 now lru
				end
				else
				begin
					way1[set][127:0] = datareadmiss;
					way1[set][149:128] = tag;
					case(blk_offset) //make sure the word is put in correct spot in the block
	        				2'b00: way1[set][31:0] = write_word;
						2'b01: way1[set][63:32] = write_word;
	        				2'b10: way1[set][95:64] = write_word;
	        				2'b11: way1[set][127:96] = write_word;
					endcase
					way1[set][149:128] = tag;
					way1[set][150] = 1;
					lru[set] = 1; //way2 now lru
				end				
				memwritethru = 0;
				state = INIT;
			end
		end	
		WRITEhit: begin
			//write the new data into the block just brough in from mem
			addymem = address;
			if(hit1 ==1) //if hit1 was 1, 
			begin
				case(blk_offset) //make sure the word is put in correct spot in the block
        				2'b00: way1[set][31:0] = write_word;
					2'b01: way1[set][63:32] = write_word;
        				2'b10: way1[set][95:64] = write_word;
        				2'b11: way1[set][127:96] = write_word;
				endcase
				way1[set][149:128] = tag;
				way1[set][150] = 1;
				lru[set] = 1; //way2 now lru
			end
			else if(hit2 ==1)
			begin
				case(blk_offset)//make sure the word is put in correct spot in the block
        				2'b00: way2[set][31:0] = write_word;
					2'b01: way2[set][63:32] = write_word;
        				2'b10: way2[set][95:64] = write_word;
        				2'b11: way2[set][127:96] = write_word;
				endcase
				way2[set][149:128] = tag;
				way2[set][150] = 1;
				lru[set] = 0; //way 1 now lru
			end
			memwritethru = 0;
			state = INIT;
		end
		READ: begin
			if(readready == 1) //how to wait for this
			begin
				if(lru[set])
				begin
					way2[set][127:0] <= datareadmiss;
					way2[set][149:128] <= tag;
					lru[set] <= 0;  
				end
				else
				begin
					way1[set][127:0] <= datareadmiss;
					way1[set][149:128] <= tag;
					lru[set] <= 1; 
				end
				data <= outmux;
				state <= INIT;
			end
		end
		endcase
	end

endmodule

// MUX 4:1 //
module mux4 #(parameter WIDTH = 32)
	(input [WIDTH-1:0] d0, d1, d2, d3, input [1:0] s, output [WIDTH-1:0] y); 
	assign y = s[1] ? (s[0] ? d3:d2):(s[0] ? d1:d0);
endmodule 

module buffer (input enable, input [127:0] datasrc, output [127:0] databus);

	assign databus = enable ? datasrc:32'h0000;

endmodule
