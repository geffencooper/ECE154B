`timescale 1ns/1ns

module reg_file_tb();
    // signal declaration
    reg [4:0] a1, a2, wr;
    reg [31:0] wd;
    wire [31:0] rd1, rd2;
    reg write_enable, rst, clk;

    // 2D array of signals and expected values for testing (11 cases)
    reg [31:0] test_cases [0:10][0:7];
    reg [31:0] expected_value1, expected_value2;

    // instantiate the module under test
    reg_file rf(
        .A1(a1),
	.A2(a2),
	.RD1(rd1),
	.RD2(rd2),
	.WR(wr),
	.WD(wd),
	.Write_enable(write_enable),
	.Rst(rst),
	.Clk(clk)
    );

    // initialize the test values
    initial 
    begin
        clk = 0;
	rst = 0;

	// read in test cases
	$readmemh("rf_tb_cases.mem", test_cases);
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
	// reset the reg file
	rst = 1; #1;

	for(i = 0; i < 11; i = i + 1)
	begin
		//$display("signals: %h | %h | %h | %h | %h | %h | %h | %h |", test_cases[i][0], test_cases[i][1], test_cases[i][2],test_cases[i][3], test_cases[i][4], test_cases[i][5], test_cases[i][6],test_cases[i][7]);
		
		// get the test case values
		a1 = test_cases[i][0][4:0];
		a2 = test_cases[i][1][4:0];
		wr = test_cases[i][2][4:0];
		wd = test_cases[i][3];
		write_enable = test_cases[i][4][0];
		rst = test_cases[i][5][0];
		expected_value1 = test_cases[i][6];
		expected_value2 = test_cases[i][7];
		#2;

		// check expected vs actual output
		if((expected_value1 != rd1) || (rd1 === 32'hxxxxxxxx) || (expected_value2 != rd2) || (rd2 === 32'hxxxxxxxx))
		begin
			$display("----Failed Case %d. Expected rd1: 0X%h | Actual: 0X%h", i, expected_value1, rd1);
			$display("                %d. Expected rd2: 0X%h | Actual: 0X%h", i, expected_value2, rd2);
		end
		else
		begin
			$display("Passed Case %d. Expected rd1: 0X%h | Actual: 0X%h", i, expected_value1, rd1);
			$display("            %d. Expected rd2: 0X%h | Actual: 0X%h", i, expected_value2, rd2);
		end
	end
    end
endmodule
