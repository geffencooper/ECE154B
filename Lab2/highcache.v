module cache 
#(parameter ROWS = 32'h00000400) //1024 rows
(input [31:0] addy, write_data, 
 input [127:0] datareadmiss, 
 input memwrite, memtoreg, readready, Rst, Clk, 
 output reg [31:0] data, datawrite, addymem, 
 output reg memwritethru, readmiss);

reg [2:0] state;
reg [2:0] prevstate;

// states
	parameter INIT  = 3'b000, // initial, wait for start signal
	READ = 3'b001, // if memtoreg == 1, and a miss
	WRITEMEM = 3'b010, // if signed, first make numbers positive
	WRITECACHE = 3'b011; // do the multiplication

	wire [17:0] tag;
	wire [9:0] set;
	wire [1:0] blk_offset;

	reg [31:0] write_word; //stored in internal reg
	reg [31:0] address;   //stored in internal reg
	
	assign tag = address[31:14];
	assign set = address[13:4];
	assign blk_offset = address[3:2]; //block size 4


	reg [146:0] way1[0:ROWS-1];  //0
	reg [146:0] way2[0:ROWS-1];  //1
	reg lru[0:ROWS-1];
	
	wire v1, v2, eq1, eq2, hit1, hit2;
	wire [127:0] data1, data2, databus, databus1, databus2;
	wire [17:0] tag1, tag2;
	wire [31:0] outmux;
	reg forcehit1, forcehit2;

	assign v1 = way1[set][146];
	assign tag1 = way1[set][145:128];
	assign data1 = way1[set][127:0];

	assign eq1 = (tag1==tag);
	assign hit1 = v1&&eq1;

	buffer buf1(.enable(hit1), .datasrc(data1), .databus(databus1));
	
	assign v2 = way2[set][146];
	assign tag2 = way2[set][145:128];
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
		for (i=0;i<ROWS;i=i+1)
		begin
			way1[i] <= 147'b0;
			way2[i] <= 147'b0;
			lru[i] <= 0;
		end

	end
	
	always @(posedge memwrite, posedge memtoreg)
	begin
		address <= addy;
		write_word <= write_data;
	end

	always @(posedge readready)
	begin
		readmiss <= 0;
		memwritethru <= 0;
	end

	always @(posedge Clk)
	begin
   		case(state)
		INIT: begin
			if ((memwrite || memtoreg) && ~Rst)
			begin
				//write_word <= write_data; //if you want to write, store that data and address in case of a miss
				//address <= addy;
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
					//change back to init ??
				end
				else if (memtoreg && ~hit)
				begin
					prevstate <= INIT;
					readmiss <= 1;
					memwritethru <= 0;
					addymem <= address;
					state <= READ;
				end
				else if (memwrite && hit)
				begin
					prevstate <= INIT;
					datawrite <= write_word;  //write through cache, so also write it to memory
					addymem <= address;
					memwritethru <= 1;
					readmiss <=0;
					state <= WRITECACHE;
				end
				else if (memwrite && ~hit)
				begin
					prevstate <= INIT;
					datawrite <= write_word;  //write through cache, so also write it to memory
					addymem <= address;
					memwritethru <= 1;
					readmiss <=1;
					state <= WRITEMEM;
				end
			end
		end
		WRITEMEM: begin
			if (prevstate == INIT)
			begin
				prevstate <= WRITEMEM;
				state <= READ;
			end
			else if (prevstate <= WRITECACHE)
			begin
				prevstate <= WRITEMEM;
				state <= INIT;
			end
		end	
		WRITECACHE: begin
			//write the new data into the block just brough in from mem
			if(hit1 ==1 || forcehit1 == 1) //if hit1 was 1, 
			begin
				case(blk_offset) //make sure the word is put in correct spot in the block
        				2'b00: way1[set][31:0] <= write_word;
					2'b01: way1[set][63:32] <= write_word;
        				2'b10: way1[set][95:64] <= write_word;
        				2'b11: way1[set][127:96] <= write_word;
				endcase
				way1[set][145:128] <= tag;
				way1[set][146] <= 1;
				lru[set] <= 1; //way2 now lru
				forcehit1 <= 0;
			end
			else if(hit2 ==1 || forcehit2 == 1)
			begin
				case(blk_offset)//make sure the word is put in correct spot in the block
        				2'b00: way2[set][31:0] <= write_word;
					2'b01: way2[set][63:32] <= write_word;
        				2'b10: way2[set][95:64] <= write_word;
        				2'b11: way2[set][127:96] <= write_word;
				endcase
				way2[set][145:128] <= tag;
				way2[set][146] <= 1;
				lru[set] <= 0; //way 1 now lru
				forcehit2 <= 0;
			end
			if (prevstate == INIT) 
			begin
				prevstate <= WRITECACHE;
				state <= WRITEMEM;
			end
			else if (prevstate == READ)
			begin
				prevstate <= WRITECACHE;
				state <= INIT;
			end
		end
		READ: begin
			if(readready == 1) //how to wait for this
			begin
				if(lru[set])
				begin
					way2[set][127:0] <= datareadmiss;
					way2[set][145:128] <= tag;
					if (prevstate == INIT)
					begin
						lru[set] <= 0;  //only want to change lru on a read miss ( if its a write miss, lru changd after WRITECACHE)
					end
					else if (prevstate == WRITEMEM)
					begin
						forcehit2 <= 1;
					end
				end
				else
				begin
					way1[set][127:0] <= datareadmiss;
					way1[set][145:128] <= tag;
					if (prevstate == INIT)
					begin
						lru[set] <= 1;  //only want to change lru on a read miss ( if its a write miss, lru changd after WRITECACHE)
					end
					else if (prevstate == WRITEMEM)
					begin
						forcehit1 <= 1;
					end
				end
				data <= outmux;
				if (prevstate == INIT)
				begin
					prevstate <= READ;
					state <= INIT;
				end
				else if (prevstate <= WRITEMEM)
				begin
					prevstate <= READ;
					state <= WRITECACHE;
				end
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
