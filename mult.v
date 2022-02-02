module mult
(
    input [31:0] SrcA, // multiplier and multiplicand
    input [31:0] SrcB, 
    output [63:0] Prod, // result
    output ProdV, // asserted when multiplication is done
    input MultStart, // asserted to start multiplication
    input MultSign, // signed or unsigned multiplication
    input Clk, // clock
    input Rst // reset
);

// intermediate product register that accumulates
reg [63:0] interm_prod;
assign Prod = interm_prod;

// intermediate registers for storing inputs
reg [31:0] srca;
reg [31:0] srcb;
reg [63:0] multiplicand;
reg [31:0] multiplier;
reg multsign;

// store  whether result is negative
reg is_negative;

// register to store state
reg [2:0] state;

// states
parameter INIT  = 3'b000, // initial, wait for start signal
	  SETUP = 3'b001, // determine the multiplicand
	  POS = 3'b010, // if signed, first make numbers positive
	  MULT = 3'b011, // do the multiplication
	  CONV = 3'b100, // convert result to 2s complement if signed
	  DONE =  3'b101; // multiplication finished

// finished multiply
assign ProdV = (state == DONE);

// reset internal registers
always @(posedge Rst)
begin
    interm_prod <= 64'h0;
    state <= INIT;
    multiplicand <= 64'h0;
    multiplier <= 32'h0;
    srca <= 32'h0;
    srcb <= 32'h0;
    is_negative <= 0;
    multsign <= 0;
end

// multiplier state  machine
always @(posedge Clk)
begin
    case(state)
    INIT: begin
	// start the multiplier
        if(MultStart == 1 && ~Rst)
	begin
            // copy in inputs because can change after a cycle
	    srca <= SrcA;
	    srcb <= SrcB;
	    multsign <= MultSign;

	    // result is negative if exactly one of the inputs is negative, ignore if unsigned
            is_negative <= SrcA[31] ^ SrcB[31];
	    
            // make the inputs positive if the multiplication is signed
	    if(MultSign)
	    begin
	        state <= POS;
	    end
	    else
	    begin
	        state <= SETUP;
    	    end
	end
	end
    POS: begin
        // if the inputs are negative (sign bit is 1), make them positive (2s compl)
	srca <= (srca[31]) ? (~srca + 1) : srca;
        srcb <= (srcb[31]) ? (~srcb + 1) : srcb;

	state <= SETUP;
        end
    SETUP: begin
	// set multiplicand to the larger input for short circuiting
	multiplicand <= (srca > srcb) ? srca :srcb;
        multiplier <= (srca > srcb) ? srcb : srca;
        state <= MULT;
	end
    MULT: begin
	// keep adding the multiplicand until it is 'shifted out',                                                                                                                                                                               i.e. first 31 bits are 0
        if(multiplier[31:0] != 32'h0)
        begin    
	    // Algorithm: each iteration, accumulate the (shifted) multiplicand if the lsb of the multiplier is a 1
	    // 1. get the lsb as a 64 bit number and take 2's complement
	    // 2. if lsb = 1 --> result = FFFFFFFFFFFFFFFF,  if lsb = 0 --> result = 0000000000000000
	    // 3. AND with multiplicand to determine if to accumulate it this iteration (add multiplicand or zero)
	    // 4. left shift the multiplicand, right shift the multiplier (get the next lsb, 0 --> stopping condition) 
              
	    //                            3._____________________________________________
	    //                                          2._____________________________      
            //                                            1. ___________________      
            interm_prod <= interm_prod + (multiplicand & (~({63'h0,multiplier[0]}) + 1 ));
	    multiplicand = multiplicand << 1;
	    multiplier = multiplier >> 1;
        end
	else
	begin
	    // convert result to 2s complement if signed
	    if(multsign)
	    begin
	        state <= CONV;
	    end
	    else
	    begin
	        state <= DONE;
	    end
	end
	end
    CONV: begin
	// if the result is negative, convert to 2s complement
        if(is_negative)
	begin
	    interm_prod <= ~interm_prod + 1;
	    state <= DONE;
	end
	// otherwise result is postive so no conversion needed
	else
	begin
	    state <= DONE;
	end
	end
    DONE: begin
	end
    endcase
end

endmodule