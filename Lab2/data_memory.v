module data_memory
#(parameter ROWS = 32'h00000040) // reduce address space to 0-0x100 (64 words)
(
    input [31:0] Address, // address to read/write
    output reg [31:0] Read_data, // data read from address
    input Write_enable, // write enable (signifies a SW instr)
    input [31:0] Write_data, // data to write to address 
    input MemtoRegM, // signifies a LW instr
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide awith 'ROWS' amount of words
reg [31:0] memory[ROWS-1:0];

// state registers that determines if the 20 cycles have passed
reg MEM_READ_READY; // low until 20 cycles passed on read
reg MEM_WRITE_READY; // low until 20 cycles passed on write
reg MEM_READ; // high while doing a read
reg MEM_WRITE; // high while doing a write
reg [4:0] delay_count; // counter register for 20 cycles

// save read/write address, and write data because could change next cycle
reg [31:0] address;
reg [31:0] write_data;


// reading and writing to memory only happens on negative clock edge and should only
// happen if we get a lw or sw (before reading was asynchronous so it happened all the time)
always @(negedge Clk)
begin
    // check reset not enabled and 20 cycles have passed
    if(~Rst && MEM_WRITE_READY)
    begin
        memory[address[31:2]] <= write_data;
	MEM_WRITE_READY <= 0;
    end
    // check reset not enabled and 20 cycles have passed
    else if(~Rst && MEM_READ_READY)
    begin
	Read_data <= memory[address[31:2]]; // [31:2] to get word address (byte addressable)
	MEM_READ_READY <= 0;
    end
end

// need to change state as soon as MemtoRegM or Write_enable change (posedge)
always @(posedge MemtoRegM, posedge Write_enable)
begin
	// if there is not currently a memory read in progress, and we want to read, start the delay
	if(~MEM_READ && MemtoRegM)
	begin
		MEM_READ <= 1;
		address <= Address;
		delay_count <= delay_count + 1; // increment now because not 'observed' till next posedge
	end
	// if there is not currently a memory wite in progress, and we want to write, start the delay
	else if(~MEM_WRITE && Write_enable)
	begin
		MEM_WRITE <= 1;
		address <= Address;
		write_data <= Write_data;
		delay_count <= delay_count + 1;
	end
end

// delay 20 clock cycles if want to read/write to memory
always @(posedge Clk)
begin
	// if a read or write is in progress and the delay has not been 20 cycles, keep waiting
	if((MEM_WRITE || MEM_READ) && (delay_count < 8'h14))
	begin
		delay_count <= delay_count + 1;
	end
	// if there is a read or write in progress and the delay has reached 20 cycles, signify the ready signal
	else if((MEM_WRITE || MEM_READ) && (delay_count == 8'h14))
	begin
		if(MEM_WRITE)
		begin
			MEM_WRITE <= 0;
			MEM_WRITE_READY <= 1;
		end
		else if(MEM_READ)
		begin
			MEM_READ <= 0;
			MEM_READ_READY <= 1;
		end
		delay_count <= 0;
	end
end

always @(posedge Rst)
begin
	MEM_READ_READY <= 0;
	MEM_WRITE_READY <= 0;
	MEM_READ <= 0;
	MEM_WRITE <= 0;
	delay_count <= 5'b0;
	address <= 32'b0;
	write_data <= 32'b0;
end

endmodule
