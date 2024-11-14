/*Top Module for SuperScalar Out-of-Order Execution Unit - 2 wide
-Good luck to me :|

### **Baseline Goals (80)**

- Implement the basic dispatch unit capable of handling two instructions per cycle.
- Instruction types to include: add/sub, mul/div, load/store, and nop.
- Support for two functional units: an adder (4 cycles) and a multiplier (6 cycles).
- Follow RISC-V Integer Instruction Set Architecture for the instructions.
- Instructions pre-stored in the instruction queue, with simulation ending when instructions run out.
- The first two instructions in the queue are connected to the two 
dispatch units
- Instruction queue will shift one or two instruction, or none, 
depending on decoding
- Ensure in-order instruction dispatch, with stalling of the second dispatch unit if the first stalls.
- To simplify the case, assume imprecise interrupt.

### **Target Goals (100)**

- Efficient handling of the instruction queue, including the capability to shift one or two instructions based on decoding.
- Implementation of Tomasulo's algorithm to allow for out-of-order execution while preserving the illusion of in-order completion.
- Incorporation of hazard detection and resolution mechanisms to manage dependencies and stalls effectively.

### **Reach Goals (+20 ea.)**

- Enhancements to the dispatch unit for improved throughput, potentially by introducing more functional units or optimizing the Tomasulo's algorithm implementation for specific instruction patterns.
- Extension of the instruction set supported, possibly including floating-point operations or complex integer operations, to test the flexibility and scalability of the implemented system.

### Hint

Start small, with the baseline goals, ensuring that the fundamental dispatch and execution mechanisms are in place and correct. Then incrementally add complexity, moving towards your target and reach goals.

1. **Core Algorithm and Execution Flow**: Master Tomasulo's algorithm, focusing on its fundamental components such as reservation stations, register renaming, and the re-order buffer to ensure efficient out-of-order execution and in-order commit, alongside developing an instruction fetch and decode unit that supports multiple instructions per cycle and directs them appropriately.
2. **Design and Optimization**: Design functional units and reservation stations while implementing mechanisms for hazard detection and resolution, particularly addressing data hazards and false dependencies through techniques like register renaming to eliminate WAR and WAW hazards and strategic use of reservation stations.
*/
import InstructionPKG::*;

module SSOOE_tb();
	//stuff
endmodule

module SSOOE(input logic clk, rst,
				 input logic [31:0] raw_i1, raw_i2,
				 //External validity flag
				 input logic valid_I1, valid_I2);
	
	localparam NUM_RS = 8;
				 
	logic i1_fetch, i2_fetch;
	logic instr_1_valid, instr_2_valid; //should be taken by DP but currently not used at all?
	Instruction_fields instr_1, instr_2;
	
	////Instruction dispatch to RS
	//[RS_ID<3-bits>, Source(1,2)<valid - 1 bit , tag - 3 (for 8 RS), value - 32>]
	logic [74:0] i1rs, i2rs;
	
	logic [1:0] bus_status1, bus_status2; //not sure what to do with this currently
	
	//Signals from RS
	logic [NUM_RS/4-1:0] add_done;
	logic [NUM_RS/4-1:0]	mul_done;
	logic [NUM_RS/4-1:0] ld_done;
	logic [NUM_RS/4-1:0]	st_done;
	
	//Register Alias Table - RAT
	//[<valid - 1 bit , tag - 3 (for 8 RS), value - 32>] rat [<num registers>]
	logic [35:0] rat [0:31]; /*32 architectural registers in RISC-V ISA*/
	
	//result broadcast register
	logic tag_result_broadcast;
	
	//Instruction Queue
	instr_queue #(2000, 16) IQ(clk, rst, raw_i1, raw_i2, 
										valid_I1, valid_I2,
										i1_fetch, instr_1_valid, 
										instr_1, i2_fetch, 
										instr_2_valid, instr_2);
	//Dispatch Unit
	du #(8, 32, 2000) DP(clk, rst, instr_1, instr_2, 
								i1_fetch, i2_fetch, i1rs, i2rs, 
								bus_status1, bus_status2, add_done, 
								mul_done, ld_done, st_done, rat);
	
	//Reservation Station
	res_station #(8) RS(clk, rst, i1rs, i2rs, add_done, mul_done, 
							  ld_done, st_done, tag_result_broadcast);
	
	//still need to design register file
	//reg_file #(//stuff) RF();
endmodule