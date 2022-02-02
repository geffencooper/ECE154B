`timescale 1ns/1ns

module data_memory_tb();
    // ---- signal declaration ----
    reg [31:0] address, write_data;
    wire [31:0] read_data;
    reg write_enable, clk, rst;

    // 2D array of signals and expected values for testing (15 cases)
    reg [31:0] test_cases [0:14][0:4];
    reg [31:0] expected_value;


    // ---- instantiate the module under test ----
    data_memory #(32'h200) mem( // reduce address space: 0-0x800 (0x200 = 512 words, byte addressable)
        .Address(address), 
        .Read_data(read_data),
        .Write_enable(write_enable),
        .Write_data(write_data),
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
        for(i = 0; i < 15; i = i + 1)
	begin
		//#2;
		// get the test case values
		address = test_cases[i][0];
		write_enable = test_cases[i][1][0]; // bit 0
		write_data = test_cases[i][2];
		rst = test_cases[i][3][0]; // bit 0
		expected_value = test_cases[i][4];
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
	end
    end
endmodule
