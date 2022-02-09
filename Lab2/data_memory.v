module data_memory
#(parameter ROWS = 32'h00000040, // reduce address space to 0-0x100 (64 words)
  parameter BLOCK_SIZE = 32'h4)  // block size in words, 4 words --> 16 bytes
(
    input [31:0] Address, // address to read/write on a miss (start of the block)
    output reg [32*BLOCK_SIZE-1:0] Read_data, // data read from address (read the whole block)
    output ReadReady, // signifies that a read has completed (Read_data is valid)
    output WriteReady, // signifies that a write has completed
    input MemWriteThrough, // write enable (signifies a SW instr, we want to write) --> comes from cache
    input [31:0] Write_data, // data to write to address (write one word)
    input ReadMiss, // signifies a LW instr, we want to read --> comes from cache
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide awith 'ROWS' amount of words
reg [31:0] memory[ROWS-1:0];

// register to store state
reg [2:0] state;

// register store delay count
reg [4:0] delay_count;

reg [31:0] read_address;

// states
parameter IDLE  = 3'b000, // start here on a rst
	  READING = 3'b001, // processing a read request (lw), waiting 20 cycles
	  WRITING = 3'b010, // processing a write request (sw), waiting 20 cycles
	  READ_READY = 3'b011, // data read from memory, Read_data is valid
	  WRITE_READY =  3'b100; // data written to memory, can continue

// notify external modules state of read/write
assign ReadReady = (state == READ_READY);
assign WriteReady = (state == WRITE_READY);

// save read/write address, and write data because could change next cycle
reg [31:0] address;
reg [31:0] write_data;

// state register for read and write on a sw miss
reg sw_miss;

integer idx;
// reset internal registers
always @(posedge Rst)
begin
	state <= IDLE;
	delay_count <= 5'b0;
	address <= 32'b0;
	read_address <= 32'b0;
	write_data <= 32'b0;
	Read_data <= 32'b0;
	sw_miss <= 0;

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
	IDLE: 	begin
			// sw miss (need to read block from cache and write word to memory simultaneously)
			if(ReadMiss && MemWriteThrough)
			begin
				sw_miss <= 1;
				address <= Address;
				state <= READING;
				write_data <= Write_data;
				delay_count <= delay_count + 1;
			end
			// lw miss
			else if(ReadMiss)
			begin
				state <= READING;
				address <= Address;
				delay_count <= delay_count + 1; // increment now because won't be observed till start of nex cycle
			end
			// sw write through (sw hit)
			else if(MemWriteThrough)
			begin
				state <= WRITING;
				address <= Address;
				write_data <= Write_data;
				delay_count <= delay_count + 1;
			end
		end
	READING:begin
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, read now so ready by 20th
			begin
				// read the whole block
				read_address = address & 32'hfffffff0; //change block offset to 0 so can grab correct block
				for(i = 0; i < BLOCK_SIZE; i = i + 1)
				begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
					// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
					read_address = read_address + (i << 2); // needs to be blocking
					start = (i << 5) + 31;
					Read_data[start-:32] = memory[read_address[31:2]];
				end
				// if it was a sw miss then we also need to update a word in the block after sending it to the cache
				if(sw_miss)
				begin
					// write one word
					memory[address[31:2]] <= write_data;
					sw_miss <= 0;
				end
				delay_count = delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles passed
			begin
				state <= READ_READY;
				delay_count <= 0;
			end
		end
	WRITING:begin
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, write now so ready by 20th
			begin
				// write one word
				memory[address[31:2]] <= write_data;
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles past
			begin
				state <= WRITE_READY;
				delay_count <= 0;
			end
		end
	READ_READY:	begin
				state <= IDLE;
			end
	WRITE_READY:	begin
				state <= IDLE;
			end
	endcase
end
endmodule