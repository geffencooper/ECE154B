module data_memory
#(parameter ROWS = 32'h00000040) // default: number of words to address 0-0xFFFFFFFF
(				 // tb init: reduce address space to 0-0x800 (512 words)
    input [31:0] Address, // address to read/write
    output [31:0] Read_data, // data read from address
    input Write_enable, // write enable
    input [31:0] Write_data, // data to write to address
    input Clk, // Clock
    input Rst // reset
);

// define the memory array, 32 bits wide awith 'ROWS' amount of words
reg [31:0] memory[ROWS-1:0];

// reading from memory is asynchronous
assign Read_data = memory[Address[31:2]]; // [31:2] to get word address (byte addressable)

// writing to memory only happens on rising clock edge
always @(negedge Clk)
begin
    // check if writing data and reset not enabled
    if(Write_enable && ~Rst)
    begin
        memory[Address[31:2]] <= Write_data;
    end
end

endmodule
