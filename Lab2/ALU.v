module ALU (input [31:0] InA, InB, input [3:0] ALUControl, output reg [31:0] out) ;
  wire [31:0] BB ;
  wire [31:0] S ;
  wire   cout ;
  
  //the first bit only determines whether or not input b is complemented or not
  assign BB = (ALUControl[3]) ? ~InB : InB ; 
  assign {cout, S} = ALUControl[3] + InA + BB;
  always @ * begin
   case (ALUControl[2:0]) 
    3'b000 : out <= InA & BB ; //and
    3'b001 : out <= InA | BB ; //or
    3'b010 : out <= S ; //add
    3'b011 : out <= {31'd0, S[31]}; //slt
    3'b100 : out <= (InA & ~BB) | (~InA & BB); //xor
   endcase
  end 
   
 endmodule