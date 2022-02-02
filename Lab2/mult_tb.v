`timescale 1ns/1ns

module mult_tb();
    // signal declaration
    reg [31:0] srca, srcb;
    wire [63:0] prod;
    wire prodV;
    reg multstart,multsign, rst, clk;

    // 2D array of signals and expected values for testing (13 cases)
    reg [63:0] test_cases [0:13][0:5];
    reg [63:0] expected_value;

    // instantiate the module under test
    mult multiplier(
        .SrcA(srca),
	.SrcB(srcb),
	.Prod(prod),
	.ProdV(prodV),
 	.MultStart(multstart),
	.MultSign(multsign),
	.Clk(clk),
	.Rst(rst)
    );

    // initialize the test values
//integer i;
    initial 
    begin
        clk = 0;
	rst = 0;

	// read in test cases
	$readmemh("mult_tb_cases.mem", test_cases);
	//i = 11;
	//$display("signals: %h | %h | %h | %h | %h | %h |", test_cases[i][0], test_cases[i][1], test_cases[i][2],test_cases[i][3], test_cases[i][4], test_cases[i][5]);
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
	for(i = 0; i < 14; i = i + 1)
	begin
		rst = test_cases[i][4][0];
		#2;
		rst = 0;
		// get the test case values
		srca = test_cases[i][0][31:0];
		srcb = test_cases[i][1][31:0];
	        multstart = test_cases[i][2][0];
		multsign = test_cases[i][3][0];
		expected_value = test_cases[i][5];
		
		// wait till multiplication done
		while(prodV != 1)
		begin
			#1;
		end

		// check expected vs actual output
		if((expected_value != prod) || (prod === 32'hxxxxxxxx))
		begin
			$display("----Failed Case %d. Expected prod: 0X%h | Actual: 0X%h", i, expected_value, prod);
		end
		else
		begin
			$display("Passed Case %d. Expected prod: 0X%h | Actual: 0X%h", i, expected_value, prod);
		end
	end
    end
endmodule
