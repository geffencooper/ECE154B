module inst_memory
#(parameter ROWS = 32'h00000200, // reduce address space to 0-0x800 (512 words)
  parameter BLOCK_SIZE = 32'h64)  // block size in words
(
    input [31:0] Address, // address to read on a miss (start of the block)
    output reg [32*BLOCK_SIZE-1:0] Read_data, // data read from address (read the whole block)
    output ReadReady, // signifies that a read has completed (Read_data is valid)
    input ReadMiss, // signifies we want to read --> comes from cache
    input abort, // if instruction after branch causes a cache miss but don't take branch, abort so we don't waste cycles loading an instrution we don't execute
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide and 'ROWS' long
reg [31:0] memory[0:ROWS-1];


// register to store state
reg [1:0] state;

// register store delay count
reg [4:0] delay_count;

// read address is the starting address of the block to read
// and must be extracted from the word address
reg [31:0] read_address;

// states
parameter IDLE  = 2'b00, // start here on a rst
	  READING = 2'b01, // processing a read request, waiting 20 cycles
	  READ_READY = 2'b10; // data read from memory, Read_data is valid

// notify external modules state of read
assign ReadReady = (state == READ_READY);

// save read address, and write data because could change next cycle
reg [31:0] address;

// reset internal registers
always @(posedge Rst)
begin
	state <= IDLE;
	delay_count <= 5'b0;
	address <= 32'b0;
	read_address <= 32'b0;
	Read_data <= 32'b0;
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
			// read instruction miss
			if(ReadMiss)
			begin
				state <= READING;
				address <= Address;
				delay_count <= delay_count + 1; // increment now because won't be observed till start of nex cycle
			end
		end
	READING:begin
			// stay in this state until the counter reaches 18 (19 cycles past since only observed after clock edge)
			if(delay_count < 8'h12)
			begin
				delay_count <= delay_count + 1;
			end
			else if(delay_count == 8'h12) // when count reads 18, 19 cycles have passed, read now so ready by 20th
			begin
				// read the whole block
				read_address = address & 32'hfffffff0; //change block offset to 0 so can grab correct block
				
				// iterate through the block and put on read bus
				for(i = 0; i < BLOCK_SIZE; i = i + 1)
				begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
					// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
					read_address = read_address + (i << 2); // needs to be blocking
					start = (i << 5) + 31;
					Read_data[start-:32] = memory[read_address[31:2]];
				end
				delay_count = delay_count + 1;
			end
			else if(delay_count == 8'h13) // 20 cycles passed
			begin
				state <= READ_READY;
				delay_count <= 0;
			end
		end
	READ_READY:	begin
				// we are ready for one cycle then go back to idle
				state <= IDLE;
			end
	endcase
end

// if we receive an abort signal, go back to idle (forget about reading from memory)
always @(posedge abort)
begin
	state <= IDLE;
end
endmodule
