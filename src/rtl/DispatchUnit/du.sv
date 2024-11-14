/*
-Dispatch Unit
-Currently have verified the basic functionality of the dispatch unit - it is not bug free and has it's quirks
*/
import InstructionPKG::*;

module du_tb();
	logic clk, reset;
	logic [31:0] INSTRUCTIONS [0:7];
	Instruction_fields instr_1, instr_2;
	logic fetch_i1, fetch_i2;
	logic [74:0] i1, i2;
	logic [1:0] bus_status1, bus_status2;
	logic [1:0] add_done, mul_done, ld_done, st_done;
	logic [35:0] rat [0:31];
	
	du #(8, 32, 2000) dut(.clk(clk), .rst(reset), .instr_1(instr_1), .instr_2(instr_2),
									 .fetch_i1(fetch_i1), .fetch_i2(fetch_i2), .i1(i1), .i2(i2),
									 .bus_status1(bus_status1), .bus_status2(bus_status2),
									 .add_done(add_done), .mul_done(mul_done), .ld_done(ld_done),
									 .st_done(st_done), .rat(rat));
	initial begin
		reset <= 1; #11; reset <= 0; 
	end
	always
		begin
			clk <= 1; #5; clk <= 0; #5;
		end
	initial begin
		/*
		Add and mul instructions
		004182b3 - add x5, x3, x4
		005203b3 - add x7, x4, x5 - RAW
		005104b3	- add x9, x2, x5
		00910133 - add x2, x2, x9 - RAW
		02538333 - mul x6, x7, x5
		03d38e33 - mul x28, x7, x29
		026382b3 - mul x5, x7, x6
		025e0eb3 - mul x29, x28, x5
		*/
		INSTRUCTIONS[0] = 32'h004182b3;
		INSTRUCTIONS[1] = 32'h005203b3;
		INSTRUCTIONS[2] = 32'h005104b3;
		INSTRUCTIONS[3] = 32'h00910133;
		INSTRUCTIONS[4] = 32'h02538333;
		INSTRUCTIONS[5] = 32'h03d38e33;
		INSTRUCTIONS[6] = 32'h026382b3;
		INSTRUCTIONS[7] = 32'h025e0eb3;
		
		//Initially, all RS are free or 'done'
		add_done = '0;
		mul_done = '0;
//		ld_done[0] = 1;
//		ld_done[1] = 1;
//		st_done[0] = 1;
//		st_done[1] = 1;
	end
	
	always @(posedge clk) begin
		if(!reset) begin
			//INSTRUCTION 1 FIELDS
			instr_1.op <= INSTRUCTIONS[$urandom_range(0,7)][6:0];
			instr_1.rd <= INSTRUCTIONS[$urandom_range(0,7)][11:7];
			instr_1.funct3 <= INSTRUCTIONS[$urandom_range(0,7)][14:12];
			instr_1.rs1 <= INSTRUCTIONS[$urandom_range(0,7)][19:15];
			instr_1.rs2 <= INSTRUCTIONS[$urandom_range(0,7)][24:20];
			instr_1.funct7 <= INSTRUCTIONS[$urandom_range(0,7)][31:25];
			
			$display("i1.op <= %b", instr_1.op);
			$display("i1.rd <= %b", instr_1.rd);
			$display("i1.funct3 <= %b", instr_1.funct3);
			$display("i1.rs1 <= %b", instr_1.rs1);
			$display("i1.rs2 <= %b", instr_1.rs2);
			$display("i1.funct7 <= %b", instr_1.funct7);
			
			//INSTRUCTION 2 FIELDS
			instr_2.op <= INSTRUCTIONS[$urandom_range(0,7)][6:0];
			instr_2.rd <= INSTRUCTIONS[$urandom_range(0,7)][11:7];
			instr_2.funct3 <= INSTRUCTIONS[$urandom_range(0,7)][14:12];
			instr_2.rs1 <= INSTRUCTIONS[$urandom_range(0,7)][19:15];
			instr_2.rs2 <= INSTRUCTIONS[$urandom_range(0,7)][24:20];
			instr_2.funct7 <= INSTRUCTIONS[$urandom_range(0,7)][31:25];
			
			$display("i2.op <= %b", instr_2.op);
			$display("i2.rd <= %b", instr_2.rd);
			$display("i2.funct3 <= %b", instr_2.funct3);
			$display("i2.rs1 <= %b", instr_2.rs1);
			$display("i2.rs2 <= %b", instr_2.rs2);
			$display("i2.funct7 <= %b", instr_2.funct7);
			
		end
		else 
			$display("waiting to assign instructions... ");
	end
	always @(negedge clk) begin //change to posedge?
		if(!reset) begin
			//control rs done signals here?
			add_done = $urandom_range(0,3);
			mul_done = $urandom_range(0,3);
		end
		else
			$display("waiting to simulate rs signals... ");
	end
endmodule

module du #(
				parameter NUM_RS = 8 /*2 rs for each fu (load/store, add/mul)*/,
				parameter NUM_REG = 32 /*2^32*/,
				parameter CLK_DELAY = 2000 /*????*/
			)
			(
				input logic clk, rst,
				//input instr_1_valid, instr_2_valid,
				input Instruction_fields instr_1, instr_2,
				output logic fetch_i1, fetch_i2,
				
				//Instruction 1 dispatch to RS
				//[RS_ID<3-bits>, Source(1,2)<valid - 1 bit , tag - 3 (for 8 RS), value - 32>]
				output logic [74:0] i1 /*<RS_ID, Source1(valid, tag, value), source2(...)>*/,
										  i2,
				//output logic i1_valid, i2_valid,
				output logic [1:0] bus_status1, bus_status2, //not sure what to do with this
				
				//Signals from RS
				input logic [NUM_RS/4-1:0] add_done,
				input logic [NUM_RS/4-1:0]	mul_done,
				input logic [NUM_RS/4-1:0] ld_done,
				input logic [NUM_RS/4-1:0]	st_done,
				
				//Register Alias Table - RAT
				//[<valid - 1 bit , tag - 3 (for 8 RS), value - 32>] rat [<num registers>]
				output logic [35:0] rat [0:NUM_REG-1]/*32 architectural registers in RISC-V ISA*/
			);

	//Define RS IDs
	//might want to change this width to 4??
	localparam a0 = 3'b000; localparam a1 = 3'b001;
	localparam m0 = 3'b010; localparam m1 = 3'b011;
	localparam ld0 = 3'b100; localparam ld1 = 3'b101;
	localparam st0 = 3'b110; localparam st1 = 3'b111;
	
//	localparam a0 = 4'b0001; localparam a1 = 4'b0010;
//	localparam m0 = 4'b0011; localparam m1 = 4'b0100;
//	localparam ld0 = 4'b0101; localparam ld1 = 4'b0110;
//	localparam st0 = 4'b0111; localparam st1 = 4'b1000;

	//RS Status table to check when a RS is free
	logic rs_status[0:NUM_RS-1];
	
	//Dispatch Logic
	logic dispatch_i1, dispatch_i2;
	
	logic [35:0] i1source1, i1source2, i2source1, i2source2;
	logic [2:0] i1_rsid, i2_rsid;
	logic raw;
	
	//Initialize rs table and rat
	initial begin
		integer i;
		for(i = 0; i < NUM_RS; i++) //foreach didn't work for some reason
			rs_status[i] = 1'b0;
		for(i = 0; i < NUM_REG; i++) begin
			rat[i][35] = 1'b1; //Registers are initially all valid
			rat[i][34:32] = 3'bx;	//tag field - which rs the register gets its value from
			rat[i][31:0] = i+1; //register value increments by 1 down the rat
		end
	end
	
	always_ff @(negedge clk) begin //On negedge because instruction queue sends i1/i2 on negedge
		//gonna be a biggie - o_o
		if(rst) begin
//			i1_valid <= '0;
//			i2_valid <= '0;
			dispatch_i1 <= '0;
			dispatch_i2 <= '0;
			i1source1 <= '0; i2source1 <= '0;
			i1source2 <= '0; i2source2 <= '0;
			i1_rsid <= 3'bx;
			i2_rsid <= 3'bx;
		end else begin
			//If high done signals - free(0)
			//Do these need else statements to make them busy(1) otherwise?
			if(add_done[0]) rs_status[a0] <= '0; if(add_done[1]) rs_status[a1] <= '0;
			if(mul_done[0]) rs_status[m0] <= '0; if(mul_done[1]) rs_status[m1] <= '0;
			if(ld_done[0]) rs_status[ld0] <= '0; if(ld_done[1]) rs_status[ld1] <= '0;
			if(st_done[0]) rs_status[st0] <= '0; if(st_done[1]) rs_status[st1] <= '0;
			
			//Check for structural hazards and perform register renaming
			////////////////////////////////////////////////////////////
			//////						INSTRUCTION 1						//////
			////////////////////////////////////////////////////////////
			case(instr_1.op)
				7'b0110011: begin	//R-type
				
					//get register operands from rat table
					i1source1 <= {rat[instr_1.rs1][35] /*valid bit*/, 
									rat[instr_1.rs1][34:32] /*tag*/, rat[instr_1.rs1][31:0]/*value*/};
					i1source2 <= {rat[instr_1.rs2][35] /*valid bit*/, 
									rat[instr_1.rs2][34:32] /*tag*/, rat[instr_1.rs2][31:0]/*value*/};
					//Update RAT using the destination address to index
					rat[instr_1.rd][35] <= 1'b0;
					rat[instr_1.rd][31:0] <= 32'b0; //value is to be set - currently undefined
					
					case(instr_1.funct7)
						7'b0000000: begin //ADD
							//Check if rs is available
							if(!rs_status[a0]) begin //is rs a0 busy?
								dispatch_i1 <= 1'b1; //dispatch i1
								i1_rsid <= a0; //Update destination register with reservation station ID("tag")
								
								rat[instr_1.rd][34:32] <= a0; //rat tag update
								
								rs_status[a0] <= 1'b1; //make add_0 busy
							end else if(!dispatch_i1 && !rs_status[a1]) begin //not dispatched and is a1 busy?
								dispatch_i1 <= 1'b1;
								i1_rsid <= a1;
								
								rat[instr_1.rd][34:32] <= a1;
								
								rs_status[a1] <= 1'b1;
							end else begin //no add rs available
								dispatch_i1 <= 1'b0;
								i1_rsid <= 1'b0;
							end
						end
						7'b0100000: begin //SUB
						end
						7'b0000001: begin //MUL/DIV
							if(instr_1.funct3 == 3'b000) begin //MUL
								if(!rs_status[m0]) begin 
									dispatch_i1 <= 1'b1;
									i1_rsid <= m0;
									
									rat[instr_1.rd][34:32] <= m0;
									
									rs_status[m0] <= 1'b1;
								end else if(!dispatch_i1 && !rs_status[m1]) begin
									dispatch_i1 <= 1'b1;
									i1_rsid <= m1;
									
									rat[instr_1.rd][34:32] <= m1;
									
									rs_status[m1] <= 1'b1;
								end else begin
									dispatch_i1 <= 1'b0;
									i1_rsid <= 1'b0;
								end
							end
							else if(instr_1.funct3 == 3'b100) begin //DIV
							end
						end
					endcase
				end
				7'b0000011: begin	//I-type
				end
				7'b0100011: begin	//S-type
				end
				default: begin //Illegal Instruction
					dispatch_i1 <= 1'b0;
				end
			endcase
			////////////////////////////////////////////////////////////
			//////						INSTRUCTION 2						//////
			////////////////////////////////////////////////////////////
			case(instr_2.op)
				7'b0110011: begin	//R-type
					//RAW DEPENDENCY CHECK
					/*
					RAW - Check if either source register in I2 are equal to the destination
					register of I1. If so, the source register should be assigned to the value
					from the related reservation station.
					
					--- Another idea (not implemented) ---
					Check if either of the source operands of I2 in 
					the rat table have tag != 0, then it's value is yet to be defined and is 
					waiting in a RS.
					*/
					/* Format : (op1 == i1_dest) ? yes (set the i2source based on the index of the 
									i1_dest in the rat) : no(index the rat table with op1)
					*/
					i2source1 <= (instr_2.rs1 == instr_1.rd) ? 
									{rat[instr_1.rd][35] /*valid bit*/, rat[instr_1.rd][34:32] /*tag*/, 
									 rat[instr_1.rd][31:0]/*value*/}
									:
									{rat[instr_2.rs1][35], rat[instr_2.rs1][34:32], 
									 rat[instr_2.rs1][31:0]};
									 
					i2source2 <= (instr_2.rs2 == instr_1.rd) ? 
									{rat[instr_1.rd][35], rat[instr_1.rd][34:32], 
									 rat[instr_1.rd][31:0]}
									: 
									{rat[instr_2.rs2][35], rat[instr_2.rs2][34:32],
									 rat[instr_2.rs2][31:0]};
					raw <= (instr_2.rs2 == instr_1.rd || instr_2.rs1 == instr_1.rd) ? 1'b1: 1'b0; //just checking, can be removed
					
					//Update RAT using the destination address to index
					rat[instr_2.rd][35] <= 1'b0;
					rat[instr_2.rd][31:0] <= 32'b0; //value is to be set - currently undefined
					
					case(instr_2.funct7)
						7'b0000000: begin //ADD
							//Check if rs is available
							if(!rs_status[a0] && i1_rsid != a0 /*i1 has not been assigned to this RS*/) begin 
								dispatch_i2 <= 1'b1; //dispatch i2
								i2_rsid <= a0; //Update destination register with reservation station ID("tag")
							
								rat[instr_2.rd][34:32] <= a0;
								
								rs_status[a0] <= 1'b1; //make add_0 busy
							end else if(!rs_status[a1] && i1_rsid != a1) begin //not dispatched and is a1 busy?
								dispatch_i2 <= 1'b1;
								i2_rsid <= a1; //update rsid
								
								rat[instr_2.rd][34:32] <= a1;
								
								rs_status[a1] <= 1'b1; //add_1 busy
							end else begin //no add rs available
								dispatch_i2 <= 1'b0;
								i2_rsid <= 1'b0;
							end
						end
						7'b0100000: begin //SUB
						end
						7'b0000001: begin //MUL/DIV
							if(instr_2.funct3 == 3'b000) begin //MUL
								if(!rs_status[m0] && i1_rsid != m0) begin 
									dispatch_i2 <= 1'b1;
									i2_rsid <= m0;
									rat[instr_2.rd][34:32] <= m0;
									rs_status[m0] <= 1'b1;
								end else if(!rs_status[m1] && i1_rsid != m1) begin
									dispatch_i2 <= 1'b1;
									i2_rsid <= m1;
									rat[instr_2.rd][34:32] <= m1;
									rs_status[m1] <= 1'b1;
								end else begin
									dispatch_i2 <= 1'b0;
									i2_rsid <= 1'b0;
								end
							end
							else if(instr_2.funct3 == 3'b100) begin //DIV
							end
						end
					endcase
				end
				7'b0000011: begin	//I-type
				end
				7'b0100011: begin	//S-type
				end
				default: begin //Illegal Instruction
					dispatch_i2 <= 1'b0;
				end
			endcase
		end
	end

	//Instruction dispatch on posedge with renamed destination sent to RS
	always_ff@(posedge clk) begin
		if(rst) begin
			i1 <= '0;
			i2 <= '0;
			fetch_i1 = 1;
			fetch_i2 = 1;
		end else begin 
			fetch_i1 <= 1'b0;
			fetch_i2 <= 1'b0;
			if(dispatch_i1) begin
				i1 <= {i1_rsid, i1source1, i1source2}; //collect i1 output
				fetch_i1 <= 1'b1;	//send the next fetch signal, new instruction will arrive on next negedge
			end
			if(dispatch_i2) begin
				i2 <= {i2_rsid, i2source1, i2source2};
				fetch_i2 <= 1'b1;
			end
		end
	end
endmodule