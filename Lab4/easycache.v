module ezcache 
#(parameter ROWS = 32'h00000040) //64 rows
(input [31:0] addy1, addy2, write_data, 
 input [127:0] datareadmiss, 
 input memwrite1, memtoreg1, memtorege1, readready, Rst, Clk, writeready,
 input memwrite2, memtoreg2, memtorege2,
 output reg [31:0] datawrite, address1, //changed from addymem -> address (and in datapath)
 output [31:0] dataout1, dataout2,
 output reg memwritethru, readmiss);

reg [2:0] state;

// states
	parameter INIT  = 3'b000, // initial, wait for start signal
	READ = 3'b001, // if memtoreg == 1, and a miss
	WRITEhit = 3'b010, // if signed, first make numbers positive
	WRITEmiss = 3'b011; // do the multiplication

	wire [21:0] tagin1,tagin2;
	wire [5:0] set1,set2;
	wire [1:0] blk_offset1,blk_offset2;

	wire hit_l;
	wire hit_2;

	reg [31:0] write_word; //stored in internal reg
	reg [31:0] addymem1,addymem2;   //stored in internal reg
	
	assign tagin1 = addy1[31:10];  //
	assign set1 = addy1[9:4];  //64 sets =  6 control bits to select right set
	assign blk_offset1 = addy1[3:2]; //block size 4

	assign tag2 = addy2[31:10];  //
	assign set2 = addy2[9:4];  //64 sets =  6 control bits to select right set
	assign blk_offset2 = addy2[3:2]; //block size 4


	reg [150:0] way1[0:ROWS-1];  //0
	reg [150:0] way2[0:ROWS-1];  //1
	reg lru[0:ROWS-1];
	
	//hit / miss identifier (based off of the diagram in the lab doc)

	wire v1, v2, eq1, eq2, hit1, hit2; 
	wire [127:0] data1, data2, databus, databus1, databus2;
	wire [22:0] tag1, tag2;
	wire [31:0] outmux;

	assign v1 = way1[set][150];		//valid bit is first bit
	assign tag1 = way1[set][149:128];	//22 bits for the tag
	assign data1 = way1[set][127:0];	//128 bits for four words

	assign eq1 = (tag1==tag);	//if the tag is same as incoming tag
	assign hit1 = v1&&eq1;		//its a hit if tags are equal and valid data in tag

	buffer buf1(.enable(hit1), .datasrc(data1), .databus(databus1));  //only let data pass if its a hit
	
	assign v2 = way2[set][150];         //same logic as way 1
	assign tag2 = way2[set][149:128];
	assign data2 = way2[set][127:0];

	assign eq2 = (tag2==tag);
	assign hit2 = v2&&eq2;

	buffer buf2(.enable(hit2), .datasrc(data2), .databus(databus2));


	// dual
	wire v1_2, v2_2, eq1_2, eq2_2, hit1_2, hit2_2; 
	wire [127:0] data1_2, data2_2, databus_2, databus1_2, databus2_2;
	wire [22:0] tag1_2, tag2_2;
	wire [31:0] outmux_2;

	assign v1_2 = way1_2[set][150];		//valid bit is first bit
	assign tag1_2 = way1_2[set][149:128];	//22 bits for the tag
	assign data1_2 = way1_2[set][127:0];	//128 bits for four words

	assign eq1_2 = (tag1_2==tagin2);	//if the tag is same as incoming tag
	assign hit1_2 = v1_2&&eq1_2;		//its a hit if tags are equal and valid data in tag

	buffer buf1_2(.enable(hit1_2), .datasrc(data1_2), .databus(databus1_2));  //only let data pass if its a hit
	
	assign v2_2 = way2_2[set][150];         //same logic as way 1
	assign tag2_2 = way2_2[set][149:128];
	assign data2_2 = way2_2[set][127:0];

	assign eq2_2 = (tag2_2==tag_2);
	assign hit2_2 = v2_2&&eq2_2;

	buffer buf2_2(.enable(hit2_2), .datasrc(data2_2), .databus(databus2_2));
	

	assign databus = databus1 | databus2;  //data that is not a hit will be zero because of the buffer
					       //so, only hits will passs
	
	assign databus_2 = databus1_2 | databus2_2;  //data that is not a hit will be zero because of the buffer
					       //so, only hits will passs

	//mux below selects the correct word from the block, sent to intermediate value, so that only set to that if its accurate/valid/needed
	mux4 blk_select(.d0(databus[31:0]), .d1(databus[63:32]), .d2(databus[95:64]), .d3(databus[127:96]), .s(blk_offset1), .y(dataout1));

	assign hit_1 = hit1||hit2; //there is a hit if either way hits

	mux4 blk_select2(.d0(databus_2[31:0]), .d1(databus_2[63:32]), .d2(databus_2[95:64]), .d3(databus_2[127:96]), .s(blk_offset2), .y(dataout2));

	assign hit_2 = hit1_2||hit2_2; //there is a hit if either way hits

	integer i;
	always @(posedge Rst)  //want everything set to zero on a reset
	begin
		state <= INIT; //ad other things on reset
		memwritethru <= 0;
		readmiss <= 0;
	 	//data <= 32'b0;
		datawrite <= 32'b0;
		addymem1 <= 32'b0;
		address1 <= 32'b0;
		addymem2 <= 32'b0;
		adress2 <= 32'b0;
		write_word <= 32'b0;
		for (i=0;i<ROWS;i=i+1)
		begin
			way1[i] <= 151'b0;
			way2[i] <= 151'b0;
			lru[i] <= 0;
		end

	end
	


	always @(posedge memwrite1, posedge memwrite2, posedge readready, posedge writeready, posedge Clk) //added posedge write_word
	begin
   		case(state)
		INIT: begin
			if (readready)
			begin
				readmiss<=0;  //resets a readmiss when going back to INIT
			end
			if ((memwrite || memtoreg) && ~Rst) //memwrite lets us know its a write to memory. memtoreg lets us know its a read
			begin
				//write_word <= write_data; //if you want to write, store that data and address in case of a miss
				address1 <= addy1;
				address2 <= addy2;
				write_word <= write_data; //write_word -> datawrite
				datawrite <= write_data;
				if (memtoreg && hit_1)	//read hit, just read the data and update lru.
				begin			//since it is so simple, no need for another state
					//data <= outmux;
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
				else if (memwrite && hit && ~readready) //write hit: tell memory to start writing the given value to the given address
				begin			  //also changes to WRITEhit state
					addymem <= address;
					memwritethru <= 1;  //write control signal to memory
					readmiss <=0;
					state <= WRITEhit;
				end
				else if (memwrite && ~hit) //write miss: tell memory to start writing new word, as well as bring in new block to cache
				begin			   //also changes to WRITEmiss state
					addymem <= address;
					memwritethru <= 1;
					readmiss <=1;
					state <= WRITEmiss;
				end
				else if (memtoreg && ~hit) //read miss: let memory know it has to start reading, gives it address as well, 
				begin			   // switches to READ state
					readmiss <= 1; //read control signal to memory
					memwritethru <= 0;
					addymem <= address;
					state <= READ;
				end
			end
		end
		WRITEmiss: begin
			if(readready == 1) //wait until readready signal before updating cache
			begin
				if(lru[set])  // if way 2 was lru, replace way2
				begin
					way2[set][127:0] = datareadmiss; //update whole block with memory block
					way2[set][149:128] = tag; //update tag
					case(blk_offset)//make sure the new word is put in correct spot in the block
	        				2'b00: way2[set][31:0] = write_word;	//this also has to be done since cache is updated after the whole new block is in cache
						2'b01: way2[set][63:32] = write_word;
	        				2'b10: way2[set][95:64] = write_word;
	        				2'b11: way2[set][127:96] = write_word;
					endcase
					//way2[set][149:128] = tag;
					way2[set][150] = 1;  //data now valid
					lru[set] = 0; //way 1 now lru
				end
				else   // if way 1 was lru, replace way1
				begin
					way1[set][127:0] = datareadmiss; // get new data from mem
					way1[set][149:128] = tag;  //update tag
					case(blk_offset) //make sure the word is put in correct spot in the block
	        				2'b00: way1[set][31:0] = write_word;
						2'b01: way1[set][63:32] = write_word;
	        				2'b10: way1[set][95:64] = write_word;
	        				2'b11: way1[set][127:96] = write_word;
					endcase
					//way1[set][149:128] = tag;
					way1[set][150] = 1; //data now valid
					lru[set] = 1; //way2 now lru
				end				
				memwritethru = 0;  //de assert the memwriththru so memory doenst write again
				state = INIT;  //change back to INIT state
			end
		end	
		WRITEhit: begin
			//write the new data into the block just brough in from mem
			addymem = address;
			if(hit1 ==1) //if hit1 was 1, update way1
			begin
				case(blk_offset) //make sure the word is put in correct spot in the block
        				2'b00: way1[set][31:0] = write_word;
					2'b01: way1[set][63:32] = write_word;
        				2'b10: way1[set][95:64] = write_word;
        				2'b11: way1[set][127:96] = write_word;
				endcase
				//way1[set][149:128] = tag;
				//way1[set][150] = 1;  //make sure data valid
				lru[set] = 1; //way2 now lru
			end
			else if(hit2 ==1)  //if hit2, then replace word in way 2
			begin
				case(blk_offset)//make sure the word is put in correct spot in the block
        				2'b00: way2[set][31:0] = write_word;
					2'b01: way2[set][63:32] = write_word;
        				2'b10: way2[set][95:64] = write_word;
        				2'b11: way2[set][127:96] = write_word;
				endcase
				//way2[set][149:128] = tag;
				//way2[set][150] = 1;  //make sure it knows data alid
				lru[set] = 0; //way 1 now lru
			end
			memwritethru = 0;  //disbale memwritethru so the memory doesnt write again
			state = INIT;  //go back to INIT
		end
		READ: begin
			if(readready == 1) //wait until the memory has valid data to read from
			begin
				if(lru[set]) //if way 2 was lru replace way2
				begin
					way2[set][127:0] = datareadmiss;  //update bwith block from memory
					way2[set][149:128] = tag;	   //update tag
					way2[set][150] = 1;		   // data now valid
					lru[set] = 0;  			   // update lru
				end
				else	//if way1 was lru replace way1
				begin
					way1[set][127:0] = datareadmiss;
					way1[set][149:128] = tag;
					way1[set][150] = 1;
					lru[set] = 1; 
				end
				//data = outmux;  //read output is the output of the hit/miss identifier earlier
				readmiss = 0;
				state = INIT;  //go back to INIT
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
