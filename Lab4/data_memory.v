module data_memory
#(parameter ROWS = 32'h00000100, // reduce address space to 0-0x100 (64 words)
  parameter BLOCK_SIZE = 32'h4)  // block size in words, 4 words --> 16 bytes
(
    input [31:0] Address1,Address2, // address to read/write on a miss (start of the block)
    output reg [32*BLOCK_SIZE-1:0] Read_data1,Read_data2, // data read from address (read the whole block)
    output ReadReady1,ReadReady2, // signifies that a read has completed (Read_data is valid)
    output WriteReady1,WriteReady2, // signifies that a write has completed
    input MemWriteThrough1,MemWriteThrough2, // write enable (signifies a SW instr, we want to write) --> comes from cache
    input [31:0] Write_data1,Write_data2, // data to write to address (write one word)
    input ReadMiss1,ReadMiss2, // signifies a LW instr, we want to read --> comes from cache
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide awith 'ROWS' amount of words
reg [31:0] memory[ROWS-1:0];

// register to store state
reg [3:0] state;

// register store delay count
reg [4:0] delay_count;

// read address is the starting address of the block to read
// and must be extracted from the word address
reg [31:0] read_address1;
reg [31:0] read_address2;

// states
parameter IDLE  = 4'b000, // start here on a rst
	  READING1 = 4'b001, // processing a read request (lw), waiting 20 cycles
	  WRITING1 = 4'b010, // processing a write request (sw), waiting 20 cycles
	  READING2 = 4'b011, // processing a read request (lw), waiting 20 cycles
	  WRITING2 = 4'b100, // processing a write request (sw), waiting 20 cycles
	  READ_READY1 = 4'b101, // data read from memory, Read_data is valid
	  WRITE_READY1 =  4'b110, // data written to memory, can continue
	  READ_READY2 = 4'b111, // data read from memory, Read_data is valid
	  WRITE_READY2 =  4'b1000; // data written to memory, can continue

// notify external modules state of read/write
assign ReadReady1 = (state == READ_READY1);
assign WriteReady1 = (state == WRITE_READY1);
assign ReadReady2 = (state == READ_READY2);
assign WriteReady2 = (state == WRITE_READY2);

// save read/write address, and write data because could change next cycle
reg [31:0] address1;
reg [31:0] curr_address1;
reg [31:0] write_data1;

reg [31:0] address2;
reg [31:0] curr_address2;
reg [31:0] write_data2;

reg second_read_req;
reg second_write_req;

reg readmiss1, readmiss2, memwritethrough1,memwritethrough2;


// state register for read and write on a sw miss
reg sw_miss1;
reg sw_miss2;

integer idx;

// reset internal registers
always @(posedge Rst)
begin
	state <= IDLE;
	delay_count <= 5'b0;
	address1 <= 32'b0;
	read_address1 <= 32'b0;
	write_data1 <= 32'b0;
	Read_data1 <= 32'b0;
	sw_miss1 <= 0;
	curr_address1 <= 0;
	address2 <= 32'b0;
	read_address2 <= 32'b0;
	write_data2 <= 32'b0;
	Read_data2 <= 32'b0;
	sw_miss2 <= 0;
	curr_address2 <= 0;
	second_read_req <= 0;
	second_write_req <= 0;
	readmiss1 <= 0;
	readmiss2 <= 0;
	memwritethrough1 <= 0;
	memwritethrough2 <= 0;

	// set the memory to all zeros to avoid xxxx...
	for(idx = 0; idx < ROWS; idx = idx + 1)
	begin
		memory[idx] <= 32'h0;
	end
end

// The data memory is now a state machine:
// Reading and writing only happen after a delay, and a 
// 'ready' state notifies external modules when the read/write 
// is considered valid

integer i; // index to loop through words in a block on read/write
integer start; // the starting bit position on a sub-block read/write
always @(posedge Clk)
begin
	case(state)
	IDLE: 	begin	// for the first three cases we handle the first instr then handle the second

			// sw miss (need to read block from cache and write word to memory simultaneously)
			if(ReadMiss1 && MemWriteThrough1)
			begin
				sw_miss1 <= 1;
				address1 <= Address1;
				state <= READING1;
				write_data1 <= Write_data1;
				write_data2 <= Write_data2;
				delay_count <= delay_count + 1;
				readmiss1 <= 1;
				memwritethrough1 <= 1;
			end
			// lw miss
			else if(ReadMiss1)
			begin
				state <= READING1;
				address1 <= Address1;
				delay_count <= delay_count + 1; // increment now because won't be observed till start of nex cycle
				readmiss1 <= 1;
			end
			// sw write through (sw hit)
			else if(MemWriteThrough1)
			begin
				state <= WRITING1;
				address1 <= Address1;
				write_data1 <= Write_data1;
				write_data2 <= Write_data2;
				delay_count <= delay_count + 1;
				memwritethrough1 <= 1;
			end

			// for these cases, there was no memory op for the first instr, only the second instr
			

			if((~ReadMiss1 && ~MemWriteThrough1) && ReadMiss2 && MemWriteThrough2)
			begin
				sw_miss2 <= 1;
				address2 <= Address2;
				state <= READING2;
				write_data2 <= Write_data2;
				delay_count <= delay_count + 1;
				readmiss2 <= 1;
				memwritethrough2 <= 1;
			end
			// only second readmiss
			else if((~ReadMiss1 && ~MemWriteThrough1) && ReadMiss2)
			begin
				state <= READING2;
				delay_count <= delay_count + 1;
				readmiss2 <= 1;
			end
			// only second write
			else if((~ReadMiss1 && ~MemWriteThrough1) && MemWriteThrough2)
			begin
				state <= WRITING2;
				delay_count <= delay_count + 1;
				memwritethrough2 <= 1;
			end
		end
	READING1:begin
			// sw miss (need to read block from cache and write word to memory simultaneously)
			if(ReadMiss2 && MemWriteThrough2 && ~second_read_req) // if also second instr sw miss
			begin
				sw_miss2 <= 1;
				address2 <= Address2;
				second_read_req <= 1;
				write_data2 <= Write_data2;
			end
			// lw miss
			else if(ReadMiss2 && ~second_read_req) // if also second instr read miss
			begin
				address2 <= Address2;
				second_read_req <= 1;
			end
			// sw write through (sw hit)
			else if(MemWriteThrough2 && ~second_write_req) // if also second instr write hit
			begin
				second_write_req <= 1;
				address2 <= Address2;
				write_data2 <= Write_data2;
			end
			// stay in this state until the counter reaches 18 (19 cycles past since only observed after clock edge)
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, read now so ready by 20th
			begin
				// read the whole block
				read_address1 = address1 & 32'hfffffff0; //change block offset to 0 so can grab correct block
				
				// iterate through the block and put on read bus
				for(i = 0; i < BLOCK_SIZE; i = i + 1)
				begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
					// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
					curr_address1 = read_address1 + (i << 2); // needs to be blocking
					start = (i << 5) + 31;
					Read_data1[start-:32] = memory[curr_address1[31:2]];
				end
				// if it was a sw miss then we also need to update a word in the block after sending it to the cache
				if(sw_miss1)
				begin
					// write one word
					memory[address1[31:2]] <= write_data1;
					sw_miss1 <= 0;
				end
				delay_count = delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles passed
			begin
				state <= READ_READY1;
				delay_count <= 0;
			end
		end
	READING2:begin
			// lw miss
			if(readmiss2)
			begin
				address2 <= Address2;
				second_read_req <= 1;
			end
			// stay in this state until the counter reaches 18 (19 cycles past since only observed after clock edge)
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, read now so ready by 20th
			begin
				// read the whole block
				read_address2 = address2 & 32'hfffffff0; //change block offset to 0 so can grab correct block
				
				// iterate through the block and put on read bus
				for(i = 0; i < BLOCK_SIZE; i = i + 1)
				begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
					// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
					curr_address2 = read_address2 + (i << 2); // needs to be blocking
					start = (i << 5) + 31;
					Read_data2[start-:32] = memory[curr_address2[31:2]];
				end
				// if it was a sw miss then we also need to update a word in the block after sending it to the cache
				if(sw_miss2)
				begin
					// write one word
					memory[address2[31:2]] <= write_data2;
					sw_miss2 <= 0;
				end
				delay_count = delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles passed
			begin
				state <= READ_READY2;
				delay_count <= 0;
			end
			
		 end
	WRITING1:begin
			if(ReadMiss2 && MemWriteThrough2 && ~second_read_req) // if also second instr sw miss
			begin
				sw_miss2 <= 1;
				address2 <= Address2;
				second_read_req <= 1;
				write_data2 <= Write_data2;
			end
			// lw miss
			else if(ReadMiss2 && ~second_read_req) // if also second instr read miss
			begin
				address2 <= Address2;
				second_read_req <= 1;
			end
			// sw write through (sw hit)
			else if(MemWriteThrough2 && ~second_write_req) // if also second instr write hit
			begin
				second_write_req <= 1;
				address2 <= Address2;
				write_data2 <= Write_data2;
			end
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, write now so ready by 20th
			begin
				// write one word
				memory[address1[31:2]] <= write_data1;
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles past
			begin
				state <= WRITE_READY1;
				delay_count <= 0;
			end
		end
	WRITING2:begin
			// sw miss (need to read block from cache and write word to memory simultaneously)
			if(readmiss2 && memwritethrough2)
			begin
				sw_miss2 <= 1;
				address2 <= Address2;
				second_write_req <= 1;
				write_data2 <= Write_data2;
			end
			// sw write through (sw hit)
			else if(memwritethrough2)
			begin
				second_write_req <= 1;
				address2 <= Address2;
				write_data2 <= Write_data2;
			end
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, write now so ready by 20th
			begin
				// write one word
				memory[address2[31:2]] <= write_data2;
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles past
			begin
				state <= WRITE_READY2;
				delay_count <= 0;
			end
		end
	READ_READY1:	begin
				if(second_read_req)
				begin
					// read the whole block
					read_address2 = address2 & 32'hfffffff0; //change block offset to 0 so can grab correct block
					
					// iterate through the block and put on read bus
					for(i = 0; i < BLOCK_SIZE; i = i + 1)
					begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
						// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
						curr_address2 = read_address2 + (i << 2); // needs to be blocking
						start = (i << 5) + 31;
						Read_data2[start-:32] = memory[curr_address2[31:2]];
					end
					// if it was a sw miss then we also need to update a word in the block after sending it to the cache
					if(sw_miss2)
					begin
						// write one word
						memory[address2[31:2]] <= write_data2;
						sw_miss2 <= 0;
					end
					// we are ready for one cycle then go back to idle
					state <= READ_READY2;
				end
				else if(second_write_req)
				begin
					// write one word
					memory[address2[31:2]] <= write_data2;
					state <= WRITE_READY2;
				end
				readmiss1 <= 0;
				memwritethrough1 <= 0;
			end
	WRITE_READY1:	begin
				if(second_read_req)
				begin
					// read the whole block
					read_address2 = address2 & 32'hfffffff0; //change block offset to 0 so can grab correct block
					
					// iterate through the block and put on read bus
					for(i = 0; i < BLOCK_SIZE; i = i + 1)
					begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
						// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
						curr_address2 = read_address2 + (i << 2); // needs to be blocking
						start = (i << 5) + 31;
						Read_data2[start-:32] = memory[curr_address2[31:2]];
					end
					// if it was a sw miss then we also need to update a word in the block after sending it to the cache
					if(sw_miss2)
					begin
						// write one word
						memory[address2[31:2]] <= write_data2;
						sw_miss2 <= 0;
					end
					state <= READ_READY2;
				end
				else if(second_write_req)
				begin
					// write one word
					memory[address2[31:2]] <= write_data2;
					state <= WRITE_READY2;
				end
				memwritethrough1 <= 0;
			end
	READ_READY2:	begin
				second_read_req <= 0;
				state <= IDLE;
				readmiss2 <= 0;
				memwritethrough2 <= 0;
			end
	WRITE_READY2:	begin
				second_write_req <= 0;
				state <= IDLE;
				memwritethrough2 <= 0;
			end
	endcase
end
endmodule