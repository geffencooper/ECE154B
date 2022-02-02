module register #(parameter WIDTH = 8)
(
    input [WIDTH-1:0] D, // input data to write to reg
    output reg [WIDTH-1:0] Q, // output data to read from reg
    input En, // enable
    input Clk, // clock
    input Clr // clear
);

// asynchronous reset
always @(posedge Clr)
begin
    Q <= 0;
end

// get the next input on the rising clock edge
always @(posedge Clk)
begin
    if(~En)
    begin
        Q <= D;
    end
end
endmodule
