package InstructionPKG;
	typedef struct packed{
		logic [6:0] op;
		logic [4:0] rd;
		logic [2:0] funct3;
		logic [4:0] rs1;
		logic [4:0] rs2;
		logic [6:0] funct7;
		//logic [11:0] imm; // for load/store - ignoring for now
 	} Instruction_fields;
endpackage