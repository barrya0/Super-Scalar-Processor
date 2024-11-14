/*
- Instruction fetch unit
- Instruction Queue
- Outputs 2 instructions on fetch request from dispatch unit
- FOR NOW THIS IS WORKING (AS FAR AS I CAN SEE:))
*/

import InstructionPKG::*;

module instr_queue_tb();
	logic clk, reset;
	logic [31:0] INSTRUCTIONS [0:7];
	logic [31:0] i1, i2;
	logic valid_I1, valid_I2;
	logic instr_1_fetch, instr_2_fetch;
	logic instr_1_valid, instr_2_valid;
	Instruction_fields instr_1, instr_2;
	
	instr_queue #(2000, 16) dut(clk, reset, i1, i2, valid_I1, valid_I2,
										instr_1_fetch, instr_1_valid, instr_1, 
										instr_2_fetch, instr_2_valid, instr_2);
	initial
		begin
			reset <= 1; # 11; reset <= 0;
		end
	always 
		begin
			clk <= 1; #5; clk <= 0; #5; 
		end
	/*NEED TO DEFINE BETTER WAY TO DRIVE INSTRUCTIONS INTO THE QUEUE AND THE INPUT SIGNALS
	 - Can verify basic functionality as is however*/
	initial begin
		/*
		Add and mul instructions
		004282b3
		005203b3
		005104b3
		00910133
		02538333
		03d38e33
		026382b3
		025e0eb3
		*/
		INSTRUCTIONS[0] = 32'h004282b3;
		INSTRUCTIONS[1] = 32'h005203b3;
		INSTRUCTIONS[2] = 32'h005104b3;
		INSTRUCTIONS[3] = 32'h00910133;
		INSTRUCTIONS[4] = 32'h02538333;
		INSTRUCTIONS[5] = 32'h03d38e33;
		INSTRUCTIONS[6] = 32'h026382b3;
		INSTRUCTIONS[7] = 32'h025e0eb3;
	end
	always_ff @(posedge clk) begin
		if(!reset) begin
			i1 <= INSTRUCTIONS[$urandom_range(0,7)];
			i2 <= INSTRUCTIONS[$urandom_range(0,7)];
			valid_I1 <= 1 /*$urandom_range(0,1)*/;
			valid_I2 <= 1 /*$urandom_range(0,1)*/;
			instr_1_fetch = $urandom_range(0,1);
			instr_2_fetch = $urandom_range(0,1);
		end
		else 
			$display("Reset high ... waiting ... ");
	end
	// Monitor outputs and display results
	always @ (posedge clk) begin
		$display("Instruction 1: %h, Validity: %b", i1, instr_1_valid);
		$display("Instruction 2: %h, Validity: %b", i2, instr_2_valid);
	end
endmodule

module instr_queue #(parameter CLK_DELAY = 2000 /*????*/,
							parameter Queue_Depth = 16)
							(input logic clk, rst,
							 input logic [31:0] instruction_1, instruction_2,
							 //External validity flag
							 input logic instruction1_valid, instruction2_valid,
							 
							 //Instruction 1 specific
							 input logic instr_1_fetch /*from du*/,
							 output logic instr_1_valid,
							 output Instruction_fields instr_1,
							 
							 //Instruction 2 specific
							 input logic instr_2_fetch,
							 output logic instr_2_valid,
							 output Instruction_fields instr_2);
	//Typedefs for the instruction queue
	typedef logic [31:0] queue [0:Queue_Depth-1];
	
	logic q1_empty, q2_empty;
	
	//Declare instruction queues
	queue instr_q1;
	queue instr_q2;
	
	//Initialize queues to 0??
	//---here---not necessary at the moment//
	
	//Pointer Widths
	localparam PTR_WIDTH = $clog2(Queue_Depth);
	
	logic [PTR_WIDTH-1:0] wr_ptr1, wr_ptr2; //Write pointers
	logic [PTR_WIDTH-1:0] rd_ptr1, rd_ptr2; //Read pointers
	
		//Currently when the read/write ptrs assume the max value they can take, they reset to 0 and the queue simply 'refreshes' itself from the head again when the queue is full, this seems to be a functioning version of the queue -- will have to figure if i want the queue to flush itself when it's full
	
	//Logic for filling up the queues
	always_ff @(posedge clk) begin
		if (rst) begin
			wr_ptr1 <= '0;
			wr_ptr2 <= '0;
		end else begin
			if(instruction1_valid) begin
				instr_q1[wr_ptr1] <= instruction_1;
				wr_ptr1 <= wr_ptr1 + 1'b1;
			end
			if(instruction2_valid) begin
				instr_q2[wr_ptr2] <= instruction_2;
				wr_ptr2 <= wr_ptr2 + 1'b1;
			end
		end
	end
	
	//If the read pointer and write pointer are equal we know the queue is empty
	assign q1_empty = (wr_ptr1 == rd_ptr1); //not working as I need to fix the logic for how/when the read ptrs and write ptrs update
	assign q2_empty = (wr_ptr2 == rd_ptr2);
	
	//Grab the Instruction fields on the negative edge if fetch from du
	always_ff @(negedge clk) begin
		if(instr_1_fetch && !q1_empty) begin
			instr_1.op <= instr_q1[rd_ptr1][6:0];
			instr_1.rd <= instr_q1[rd_ptr1][11:7];
			instr_1.funct3 <= instr_q1[rd_ptr1][14:12];
			instr_1.rs1 <= instr_q1[rd_ptr1][19:15];
			instr_1.rs2 <= instr_q1[rd_ptr1][24:20];
			instr_1.funct7 <= instr_q1[rd_ptr1][31:25];
			//Immediate not yet implemented		
		end
		if(instr_2_fetch && !q2_empty) begin
			instr_2.op <= instr_q2[rd_ptr2][6:0];
			instr_2.rd <= instr_q2[rd_ptr2][11:7];
			instr_2.funct3 <= instr_q2[rd_ptr2][14:12];
			instr_2.rs1 <= instr_q2[rd_ptr2][19:15];
			instr_2.rs2 <= instr_q2[rd_ptr2][24:20];
			instr_2.funct7 <= instr_q2[rd_ptr2][31:25];
			//Immediate not yet implemented
		end
	end
	//Update the read pointers with a clock delay of 2000
	always_ff @(posedge clk) begin //cannot be combinational for now - need to decide if it needs to be later
		if(rst) begin
			rd_ptr1 <= '0;
			rd_ptr2 <= '0;
		end else begin
			if(instr_1_fetch && !q1_empty)
				/*#CLK_DELAY*/ rd_ptr1 <= rd_ptr1 + 1'd1;
				else begin
					rd_ptr1 <= rd_ptr1;
				end
			if(instr_2_fetch && !q2_empty)
				/*#CLK_DELAY*/ rd_ptr2 <= rd_ptr2 + 1'd1;
		end
	end
	//Drive valid instruction signal to du at negedge
	always_ff @(negedge clk) begin
		//Instruction 1
		if(instr_1_fetch && !q1_empty)
			instr_1_valid <= 1'b1;
		else
			/*#CLK_DELAY*/ instr_1_valid <= 1'b0;
		//Instruction 2
		if(instr_2_fetch && !q2_empty) 
			instr_2_valid <= 1'b1;
		else
			/*#CLK_DELAY*/ instr_2_valid <= 1'b0;
	end
	
endmodule