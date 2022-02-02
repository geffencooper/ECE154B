module inst_memory
#(parameter ROWS = 32'h00000200) // reduce address space to 0-0x800 (512 words)
(
    input [31:0] Address, // address in memory
    output [31:0] Read_data // instruction read from address
);

// define the memory array, 32 bits wide and 'ROWS' long
reg [31:0] memory[0:ROWS-1];

// reading from memory is asynchronous
assign Read_data = memory[Address[31:2]]; // [31:2] to get word address (mem is byte addressable)

endmodule
