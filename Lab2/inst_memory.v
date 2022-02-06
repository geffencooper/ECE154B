module inst_memory
#(parameter ROWS = 32'h00000040, // reduce address space to 0-0x100 (64 words)
  parameter BLOCK_SIZE = 32'h1)  // block size in words, 4 words --> 16 bytes
(
    input [31:0] Address, // address in memory
    output reg [32*BLOCK_SIZE-1:0] Read_data, // data read from address (read the whole block)
    output ReadReady, // signifies that a read has completed (Read_data is valid)
    input ReadMiss, // signifies a load, we want to read --> comes from cache
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide and 'ROWS' long
reg [31:0] memory[0:ROWS-1];

// register to store state
reg [1:0] state;

// register store delay count
reg [4:0] delay_count;

// states
parameter IDLE  = 2'b00, // start here on a rst
	  READING = 2'b01, // processing a read request, waiting 20 cycles
	  READ_READY = 2'b10; // data read from memory, Read_data is valid

// notify external modules state of read
assign ReadReady = (state == READ_READY);

// save read address because could change next cycle
reg [31:0] address;

// reset internal registers
always @(posedge Rst)
begin
	state <= IDLE;
	delay_count <= 5'b0;
	address <= 32'b0;
	Read_data <= 32'b0;
end

// The instruction memory is now a state machine:
// Reading only happens after a delay, and a 
// 'ready' state notifies external modules when the read
// is considered valid

integer i; // index to loop through words in a block on read
integer start; // the starting bit position on a sub-block read
always @(posedge Clk)
begin
	case(state)
	IDLE: 	begin
			if(ReadMiss)
			begin
				state <= READING;
				address <= Address;
				delay_count <= delay_count + 1; // increment now because won't be observed till start of nex cycle
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
				for(i = 0; i < BLOCK_SIZE; i = i + 1)
				begin   // Read_data[(i*32) + 31 : i*32]  --> this gets each word in the block indivually (e.g. read_data[31:0], read_data[63:32])
					// memory[(address + i*4)[31:2]]--> this gets the next word address (e.g. 0x00, 0x04, 0x08, 0x0C)
					address = address + (i << 2); // needs to be blocking
					start = (i << 5) + 31;
					Read_data[start-:32] = memory[address[31:2]];
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
				state <= IDLE;
			end
	endcase
end

endmodule
