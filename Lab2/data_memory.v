module data_memory
#(parameter ROWS = 32'h00000040, // reduce address space to 0-0x100 (64 words)
  parameter BLOCK_SIZE = 32'h4)  // block size in words, 4 words --> 16 bytes
(
    input [31:0] Address, // address to read/write on a miss (start of the block)
    output reg [32*BLOCK_SIZE-1:0] Read_data, // data read from address (read the whole block)
    output ReadReady, // signifies that a read has completed (Read_data is valid)
    output WriteReady, // signifies that a write has completed
    input MemWriteThrough, // write enable (signifies a SW instr, we want to write) --> comes from cache
    input [32*BLOCK_SIZE-1:0] Write_data, // data to write to address (write the whole block)
    input ReadMiss, // signifies a LW instr, we want to read --> comes from cache
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide awith 'ROWS' amount of words
reg [31:0] memory[ROWS-1:0];

// INTERNAL state registers that signify 20 cycles have passed and we can read/write to data memory
// Note: the actual read/write only happens on the negedge clock
reg READ_DELAY_COMPLETE; // low until 20 cycles passed on read
reg WRITE_DELAY_COMPLETE; // low until 20 cycles passed on write
reg READING; // high while doing a read
reg WRITING; // high while doing a write
reg [4:0] delay_count; // counter register for 20 cycles

// registers that signify that a read or write has completed
reg read_ready;
reg write_ready;

// notify external modules state of read/write
// Note: these signals will go high on posedge clock then reset on negedge clock when we do the read/write
assign ReadReady = read_ready;
assign WriteReady = write_ready;

// save read/write address, and write data because could change next cycle
reg [31:0] address;
reg [32*BLOCK_SIZE-1:0] write_data;


// reading and writing to memory only happens on negative clock edge and should only
// happen if we get a lw or sw from a cache miss (before reading was asynchronous so it happened all the time)
integer i;
integer start;
always @(negedge Clk)
begin
    // check reset not enabled and 20 cycles have passed
    if(~Rst && WRITE_DELAY_COMPLETE)
    begin
	// write the whole block
	for(i = 0; i < BLOCK_SIZE; i = i + 1)
	begin   // memory[(address + i*4)[31:2]] --> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
		// write_data[(i*32) + 31 : i*32] --> this write each word in the block indivually (e.g. write_data[31:0], write_data[63:32])
		address = address + (i << 2); // need to be blocking
		start = (i << 5) + 31;
$display("add: %h, mem[add]: %h, write_data: %h",address,memory[address[31:2]],write_data[start-:32]);
		memory[address[31:2]] = write_data[start-:32];
$display("add: %h, mem[add]: %h, write_data: %h",address,memory[address[31:2]],write_data[start-:32]);
	end
	WRITE_DELAY_COMPLETE = 0;
	write_ready = 1;
    end
    // check reset not enabled and 20 cycles have passed
    else if(~Rst && READ_DELAY_COMPLETE)
    begin
	// read the whole block
	for(i = 0; i < BLOCK_SIZE; i = i + 1)
	begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
		// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
		address = address + (i << 2); // need to be blocking
		start = (i << 5) + 31;
		Read_data[start-:32] = memory[address[31:2]];
	end
	READ_DELAY_COMPLETE = 0;
	read_ready = 1;
    end
end

// check if we receive a read/write request from cache
// need to change state right after the request is received (posedge)
always @(posedge ReadMiss, posedge MemWriteThrough)
begin
	// if there is not currently a memory read in progress, and we want to read, start the delay
	if(~READING && ~WRITING && ReadMiss)
	begin
		READING <= 1;
		read_ready <= 0;
		write_ready <= 0;
		address <= Address;
		delay_count <= delay_count + 1; // increment now because not 'observed' till next posedge
	end
	// if there is not currently a memory wite in progress, and we want to write, start the delay
	else if(~WRITING && ~READING && MemWriteThrough)
	begin
		WRITING <= 1;
		write_ready <= 0;
		read_ready <= 0;
		address <= Address;
		write_data <= Write_data;
		delay_count <= delay_count + 1;
	end
end

// delay 20 clock cycles if want to read/write to memory
always @(posedge Clk)
begin
	// if a read or write is in progress and the delay has not been 20 cycles, keep waiting
	if((WRITING || READING) && (delay_count < 8'h14))
	begin
		delay_count <= delay_count + 1;
	end
	// if there is a read or write in progress and the delay has reached 20 cycles, signify the ready signal
	else if((WRITING || READING) && (delay_count == 8'h14))
	begin
		if(WRITING)
		begin
			WRITING <= 0;
			WRITE_DELAY_COMPLETE <= 1;
		end
		else if(READING)
		begin
			READING <= 0;
			READ_DELAY_COMPLETE <= 1;
		end
		delay_count <= 0;
	end
end

always @(posedge Rst)
begin
	READ_DELAY_COMPLETE <= 0;
	WRITE_DELAY_COMPLETE <= 0;
	READING <= 0;
	WRITING <= 0;
	delay_count <= 5'b0;
	address <= 32'b0;
	write_data <= 32'b0;
	Read_data <= 32'b0;
	read_ready <= 0;
	write_ready <= 0;
end

endmodule
