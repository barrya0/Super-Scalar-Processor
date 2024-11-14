module add_tb();
	logic clk, rst, ena;
	logic [31:0] a, b;
	logic busy;
	logic [31:0] result;
	logic valid;
	
	add dut(clk, rst, ena, a, b, result, busy, valid);
	
	always begin
		clk <= 1; #5; clk <= 0; #5;
	end
	
	initial begin
		rst = 1; #11; rst = 0;
		a = 32'd10;
		b = 32'd2;
		ena = 1;
		#60;
		$stop;
	end
	always_comb begin
		if(!busy && !rst)
			$display("Result is %d", result);
	end
endmodule

//4-cycle adder unit
module add(
    input logic clk,      // Clock input
    input logic rst,
	 input logic ena,
    input logic [31:0] a, // Operand A
    input logic [31:0] b, // Operand B
    output logic [31:0] result, // Result of addition
    output logic busy,     // Indicates busy state of adder unit
	 output logic valid
);


	// Registers
	logic [2:0] cycle_count;

	always_ff @(negedge clk) begin
		if(rst) begin
			result <= '0;
			busy <= 1'b0;
			cycle_count <= 0;
			valid <= 1'b0;
		end else begin
			if(ena) begin
				valid <= 1'b0;
				if(cycle_count < 3) begin
					cycle_count <= cycle_count + 1'd1;
					busy <= 1'b1;
				end else begin
					result <= a+b;
					busy <= 1'b0;
					cycle_count <= 0;
					valid <= 1'b1;
				end
			end
		end
	end

endmodule
