`timescale 1ns/1ns

module data_memory_tb();
    // ---- signal declaration ----
    reg [31:0] address;
    reg [63:0] write_data;
    wire [63:0] read_data;
    wire ReadReady,WriteReady;
    reg ReadMiss,MemWriteThrough, clk, rst;

    // 2D array of signals and expected values for testing (3 cases) --> test block size of 2
    reg [63:0] test_cases [0:2][0:5];
    reg [63:0] expected_value;


    // ---- instantiate the module under test ----
    data_memory #(32'h040,32'h2) mem( // reduce address space: 0-0xFC (0x40 = 64 words, byte addressable), block size = 2
        .Address(address), 
        .Read_data(read_data),
	.ReadReady(ReadReady),
	.WriteReady(WriteReady),
	.MemWriteThrough(MemWriteThrough),
        .Write_data(write_data),
	.ReadMiss(ReadMiss),
        .Clk(clk),
	.Rst(rst)
    );

    // ---- initialize the test values ----
    initial 
    begin
        clk = 0;
	
	// initialize memory to zeros
	$readmemh("data_mem_init.mem", mem.memory);

	// read in test cases
	$readmemh("dmem_tb_cases.mem", test_cases);
    end

    // run the clock
    always
    begin
        // next clock cycle
	#1;
        clk = ~clk;
    end

    // go through test cases
    integer i;
    initial 
    begin
	rst = 1; #3; rst = 0;
        for(i = 1; i < 3; i = i + 1)
	begin
		// get the next test case values
		address = test_cases[i][0][31:0];
		MemWriteThrough = test_cases[i][1][0]; // bit 0
		write_data = test_cases[i][2];
		ReadMiss = test_cases[i][3][0]; // bit 0
		expected_value = test_cases[i][5];
		//$display("Vals %h\t%h\t%h\t%h\t%h\t%h", address, MemWriteThrough, write_data, ReadMiss,rst,expected_value);
		
		// wait for the read/write request to complete
		while((~ReadReady && ReadMiss) || (~WriteReady && MemWriteThrough))
		begin
			#1; // in the pipeline we will detect this asynchronously
		end

		// once we finish the read/write, deassert the request
		MemWriteThrough = 0;
		ReadMiss = 0;
		
		// continue on the next posedge
		#2;
		//$display("rr: %h, wr: %h",ReadReady,WriteReady);
		// check expected vs actual output
		if((expected_value != read_data) || (read_data === 64'hxxxxxxxx))
		begin
			$display("----Failed Case %d. Expected: 0X%h | Actual: 0X%h", i, expected_value, read_data);
		end
		else
		begin
			$display("Passed Case %d. Expected: 0X%h | Actual: 0X%h", i, expected_value, read_data);
		end
	end
    end
endmodule
