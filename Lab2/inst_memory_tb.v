`timescale 1ns/1ns

module inst_memory_tb();
    // signal declaration
    reg [31:0] PC; // program counter (address)
    wire [31:0] read_data;
    reg clk;

    // array of signals and expected values for testing (10 cases)
    reg [31:0] test_cases [0:9];
    reg [31:0] expected_value;

    // instantiate the module under test
    inst_memory #(32'h00000200) mem( // reduce address space: 0-0x800 (0x200 = 512 words, byte addressable)
        .Address(PC), 
        .Read_data(read_data)
    );

    // initialize the test values
    initial 
    begin
        clk = 0;
	
	// initialize the instruction memory
	$readmemh("inst_mem.mem", mem.memory);

	// load the test cases
	$readmemh("imem_tb_cases.mem", test_cases);
    end

    // run the clock
    always
    begin
        // next clock cycle
	#1;
        clk = ~clk;
    end

    // write the test signals
    integer i;
    initial 
    begin
        // read the first ten instructions
        PC = 32'h00000000;
	for(i = 0; i < 10; i = i + 1)
	begin
		// get the test case values
		expected_value = test_cases[i];
		#2;

		// check expected vs actual output
		if((expected_value != read_data) || (read_data === 32'hxxxxxxxx))
		begin
			$display("----Failed Case %d. Expected: 0X%h | Actual: 0X%h", i, expected_value, read_data);
		end
		else
		begin
			$display("Passed Case %d. Expected: 0X%h | Actual: 0X%h", i, expected_value, read_data);
		end

		// next test case (increment the program counter)
		PC = PC + 4; 
	end
    end
endmodule
