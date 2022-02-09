module icache 
#(parameter ROWS = 32'h00000001) //1 rows
(input [31:0] addy, 
 input [127:0] datareadmiss, 
 input readready, Rst, Clk,
 output reg [31:0] data, address, 
 output reg readmiss);

reg [2:0] state;

// states
	parameter INIT  = 3'b000, // initial, wait for start signal
	READ = 3'b001; // if memtoreg == 1, and a miss

	wire [17:0] tag;
	wire [1:0] blk_offset;

	reg [31:0] addymem;   //stored in internal reg
	
	assign tag = address[31:14];
	assign blk_offset = address[3:2]; //block size 4


	reg [146:0] way1; //update number of bits
	
	wire v1, eq1, hit1;
	wire [127:0] data1, databus1;
	wire [17:0] tag1;

	assign v1 = way1[146];
	assign tag1 = way1[145:128];
	assign data1 = way1[127:0];

	assign eq1 = (tag1==tag);
	assign hit1 = v1&&eq1;

	buffer buf1(.enable(hit1), .datasrc(data1), .databus(databus1));
	
	integer i;
	always @(posedge Rst)
	begin
		state <= INIT; //ad other things on reset
		readmiss <= 0;
	 	data <= 32'b0;
		addymem <= 32'b0;
		address <= 32'b0;
		way1 = 1'b0; //update number of bits

	end
	


	always @(posedge readready, posedge Clk) //added posedge write_word
	begin
   		case(state)
		INIT: begin
			if (readready)
			begin
				readmiss<=0;
			end
			if (~Rst)
			begin
				//write_word <= write_data; //if you want to write, store that data and address in case of a miss
				address <= addy;
				if (hit1)
				begin
					data <= databus1;
					readmiss <= 0;
				end
				else if (~hit1)
				begin
					readmiss <= 1;
					addymem <= address;
					state <= READ;
				end
			end
		end
		READ: begin
			if(readready == 1) //how to wait for this
			begin
				way1[127:0] <= datareadmiss;
				way1[145:128] <= tag;
				data <= databus1;
				state <= INIT;
			end
		end
		endcase
	end

endmodule


module buffer (input enable, input [127:0] datasrc, output [127:0] databus);

	assign databus = enable ? datasrc:32'h0000; //update bit numbers

endmodule
