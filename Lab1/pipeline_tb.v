`timescale 1ns/1ns

module pipeline_tb();
    // signal declaration
    reg clk, rst;

    // instantiate data path
    datapath data_path(
        .CLK(clk),
        .RESET(rst)
    );
    
    initial
    begin
        clk = 0;
        rst = 0;
        
        // initialize instruction memory
        $readmemh("inst_mem.mem", data_path.imem.memory);
    end

    // run the clock
    always
    begin
        // next clock cycle
	#1;
        clk = ~clk;
    end

    // test
    integer i;
    initial
    begin
	// global reset for all registers
	#1;
        rst = 1;
        #2;
        rst = 0;
        
        // execute for 100 cycles
	for(i = 0; i < 100; i = i + 1)
	begin
	    #2;
	end
    end
endmodule
