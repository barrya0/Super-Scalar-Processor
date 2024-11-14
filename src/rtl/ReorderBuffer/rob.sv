/*
3 - Reorder Buffer
This project is an incremental addition to the previous one, focusing on implementing in-order commit/completion using a Reorder Buffer (ROB). As this project should be completed within 2 week or so, feel free to make reasonable assumptions to reduce workload, as long as you state them clearly in your report (e.g. limited data dependencies).
***********BASELINE GOALS (80)***********
- Extend the previous project by implementing a Reorder Buffer (ROB) to ensure in-order commit of instructions, even with out-of-order execution. The ROB should hold information about all decoded but not yet committed instructions.
- Each ROB entry should include fields for:
	- Instruction type and operands
	- Destination register
	- Completion status
	- Exception status
	- …And fields that will facilitate your implementation
Modify the dispatch unit from the previous project to allocate ROB entries for each dispatched instruction.
Update the ROB entries as instructions complete execution.
Implement the commit stage, which checks the head of the ROB and commits instructions in-order if they have completed without exceptions.
Handle branch mispredictions and exceptions by flushing the ROB and restarting execution from the correct path.
***********TARGET GOALS (100)***********
- Implement a mechanism to handle precise exceptions, ensuring that all instructions before the excepting instruction have committed and none after it have modified architectural state.
***********REACH GOALS(+20 ea.)***********
- Optimize ROB usage by allowing early release of entries for instructions that do not produce a register result (e.g., stores).
- Enhance the branch misprediction handling by implementing a more efficient ROB flushing mechanism.
- Implement a more advanced branch prediction mechanism (e.g., two-level adaptive predictor) and integrate it with the ROB for more efficient speculation.
***********HINT***********
Focus first on getting the basic ROB functionality working, with in-order commit and then correct handling of exceptions and mispredictions. Remember, you can make reasonable assumptions to simplify the implementation, as long as you document them in your report. Thoroughly test each new feature before moving on to the next.
*/

/*
ROB Organization and Notes
- A circular queue with head and tail ptrs, tail is out, head in
	- Tail Ptr (next to commit)
	- Head Ptr (next available)
- Holds information about all instructions that are decoded but not yet retired (committed)
- 16 entries
- In a 2-way cpu, you can have at most 2 decoded instructions at once, so ROB should be able to handle max 2 instruction entries on a 		clock cycle - I have not implemented this functionality fully, only supports single instruction entry at a time
- Sources invalid until they have a value
- Must be able to handle value from each function unit on the same clock cycle

- When an instruction is decoded, it 
	reserves the next-sequential entry in 
	the ROB
- When an instruction completes, it 
	writes result into ROB entry
- When the oldest instruction in ROB 
	has completed without exceptions, it 
	commits the result to reg. file or 
	memory
- Issue
	- Enter opcode and tag or data (if known) for each source
	- I take this to mean the DU will mark the value of destination registers to the RS they will get their value from.
		  Then, when an instruction executes, the broadcasted tag and value will be searched for in the ROB and value will be updated
	- Enter RF# in “destReg” field in ROB
- Execute
	- Execute instruction when all sources available
- Writeback
	- Replace tag with data as it becomes available
	- Save data in “Value” field of ROB (instead of in RF) and exception flag
- Commit
	- If no exception, save data into Architectural Register File (ARF)

- Handle Mispredictions and Exceptions:
	1. Clear reorder buffer by resetting Head Ptr == Tail Ptr
	2. In RAT, clear valid bits for all “dest” RFs between Tail and Head 
		Ptrs
	3. Fetch PC handler (exception) or Branch Target (branch 
		mispredict)
*/

module rob_tb();
	logic clk, rst;
	logic write_ena, valid_add, valid_mul, full;
	logic [6:0] opcode;
	logic [2:0] src1, src2, tag;
	logic [4:0] destReg;
	logic [34:0] add_trb, mul_trb;
	logic [4:0] exception;
	logic [36:0] commitVal;
	logic stall;
	rob #(16) dut(clk, rst, write_ena, opcode, valid_add, valid_mul, src1, src2, 
						destReg, tag, add_trb, mul_trb, exception, commitVal, full, stall);
	
	always begin
		clk <= 1; #5; clk <= 0; #5;
	end
	initial begin
		rst <= 1; #11; rst <= 0;
		
		valid_add <= 1'b0; valid_mul <= 1'b0;
		exception <= '0;
		add_trb <= '0; mul_trb <= '0;
		
		#40;
		//Testing for ROB update on sample adder and multiplier <tag,value> broadcast
		valid_add <= 1'b1;
		add_trb <= {3'b001, 32'd128};
		valid_mul <= 1'b1;
		mul_trb <= {3'b100, 32'd64};
		
		#20;
		valid_add <= 1'b0;
		add_trb <= '0;
		valid_mul <= 1'b0;
		mul_trb <= 'x;
		
		#20;
		//Purposefully broadcasting a value to the tail of the buffer to check the commit stage
		valid_add <= 1'b1;
		add_trb <= {3'b101, 32'd12};
		exception <= 5'b10110;
		
		#20;
		valid_add <= 1'b0;
		add_trb <= '0;
		valid_mul <= 1'b0;
		exception <= '0;
	end
	always_ff @(negedge clk) begin
		if(!full) begin
			//Just looking for basic population of ROB with decoded instructions
			opcode <= $urandom_range(0,64);
			src1 <= $urandom_range(0,6);
			src2 <= $urandom_range(0,6);
			destReg <= $urandom_range(0,31);
			tag <= $urandom_range(0,6);
			write_ena <= 1'b1;
		end
//		if(full)
//			$stop;
	end
endmodule

module rob #(parameter ROB_DEPTH = 16)
				(
				input logic clk, rst,
				input logic write_ena, //from du? - have 2 separate write ena, one from du other from rs?
				input logic [6:0] opcode,
				input logic valid_add, valid_mul, //from res station when a value is ready to be broadcast to rob
				input logic [2:0] src1, src2, //For now, the sources will be the renamed registers the du assigns to instructions - tags of renamed registers are width 3
				input logic [4:0] destReg,
				input logic [2:0] tag, //renamed tag for dest-reg, will allow for value placement when executed
				input logic [34:0] add_trb, mul_trb, //<3-bit tag for RS, 32-bit value> - immediate broadcast from RS and can update
				input logic [4:0] exception, //destReg # that encountered exception
				output logic [36:0] commitVal, //Delayed broadcast to ARF that must wait to reach the tail of the queue with no exceptions <Register - 5 bits, val - 32>
				output logic full, stall
				);

	typedef struct packed{
		logic busy;
		logic exec;
		logic [6:0] op;
		logic v1;
		logic [31:0] src1;
		logic v2;
		logic [31:0] src2;
		logic [4:0] destReg;
		logic [31:0] value;
		logic except;
	} rob_entry;
	
	rob_entry rob_table [0:ROB_DEPTH-1];
	
	initial begin
		for(int i = 0; i < ROB_DEPTH; i++) begin
			rob_table[i].busy = 1'b0;
			rob_table[i].exec = 1'b0;
			rob_table[i].op = '0;
			rob_table[i].v1 = 1'b0;
			rob_table[i].src1 = '0;
			rob_table[i].v2 = 1'b0;
			rob_table[i].src2 = '0;
			rob_table[i].destReg = '0;
			rob_table[i].value = '0;
			rob_table[i].except = 1'b0;
		end
	end

	logic [4:0] head_ptr, tail_ptr;
	logic empty, broadcast;
	
	assign full = (head_ptr == ROB_DEPTH) ? 1'b1 : 1'b0;
	assign empty = (head_ptr == tail_ptr) ? 1'b1 : 1'b0; //-- not sure if i need this lol
	
	//population - synchronized with du
	always_ff @(negedge clk) begin
		if(rst) begin
			head_ptr <= 0; tail_ptr <= 0;
			stall <= 1'b0;
		end else begin
			if(write_ena && !full) begin //entry update at head ptr
				rob_table[head_ptr].op <= opcode;
				rob_table[head_ptr].src1 <= {29'b0, src1}; //assign sources to LS 3 bits
				rob_table[head_ptr].src2 <= {29'b0, src2};
				rob_table[head_ptr].destReg <= destReg;
				rob_table[head_ptr].value <= {29'b0, tag}; //assign value to tag for now, will be updated to value after execute
				rob_table[head_ptr].busy <= ~rob_table[head_ptr].exec; //entry becomes busy when it enters; surely an entry cannot be busy and executed at the same time - right?
				
				head_ptr <= head_ptr + 1'b1;
			end
			
			if(full && !rob_table[tail_ptr].except && rob_table[tail_ptr].exec) begin //rob full, tail can commit only if entry at tail_ptr has no exception and has been executed!
				commitVal <= {rob_table[tail_ptr].destReg, rob_table[tail_ptr].value};
				//either flush old entry here - should pop the old entry, increment tail ptr and increment headptr? - shift rob??
				rob_table[tail_ptr].busy <= 1'b0;
				rob_table[tail_ptr].exec <= 1'b0;
				rob_table[tail_ptr].op <= '0;
				rob_table[tail_ptr].v1 <= 1'b0;
				rob_table[tail_ptr].src1 <= '0;
				rob_table[tail_ptr].v2 <= 1'b0;
				rob_table[tail_ptr].src2 <= '0;
				rob_table[tail_ptr].destReg <= '0;
				rob_table[tail_ptr].value <= '0;
				rob_table[tail_ptr].except <= 1'b0;
				
				if(write_ena)
					head_ptr <= tail_ptr; //rob is full so headptr next will wrap around to the new/popped (blank) entry
				
				tail_ptr <= tail_ptr + 1'b1; //update tail_ptr
			end else if(full && rob_table[tail_ptr].except) begin //there is an exception on the next instruction to be committed - oh no!
				//clear by setting head_ptr = tail_ptr
				head_ptr <= tail_ptr; //this will begin refresh/reset of rob
				//need to add logic for clearing valid bits for all "dest" RFs between tail and head ptrs
				//Fetch PC handler - (?) not done yet
				for(int i = 0; i < ROB_DEPTH; i++) begin
					rob_table[i].busy = 1'b0;
					rob_table[i].exec = 1'b0;
					rob_table[i].op = '0;
					rob_table[i].v1 = 1'b0;
					rob_table[i].src1 = '0;
					rob_table[i].v2 = 1'b0;
					rob_table[i].src2 = '0;
					rob_table[i].destReg = '0;
					rob_table[i].value = '0;
					rob_table[i].except = 1'b0;
				end
			end else if(full && !rob_table[tail_ptr].exec) begin
				//corner case
				//cannot commit value at tail - stall??
				//options: blocking so yes stall pipeline
				// or dynamic priority on instruction overwrite?
				stall <= 1'b1; //flag for now
			end
			
			if(exception != '0) begin //there is an exception at a destReg
				for(int i = 0; i < ROB_DEPTH; i++) begin
					if(rob_table[i].destReg == exception)
						rob_table[i].except <= 1'b1;
				end
			end
			
			// On value broadcast - check if other entries need data from destination reg that got it's value
			// Essentially look for dependent entries in the ROB - if found, mark related source as valid
			// based on tag of function unit broadcast
			
			// NOTE: From posedge ff(commented out below) - used to work in there but suddenly started throwing multiple constant driver error?? 
			// IDK quartus is making me sad as the design compiles in modelsim just fine
			
			// Bug: need to change these case statements so they don't assign or change entries when one broadcast is 0
			if((valid_add && add_trb /*broadcast is not 0*/) || (valid_mul && mul_trb)) begin //if most
				for(int i = 0; i < ROB_DEPTH; i++) begin
					//Checking for associated destReg's with undefined value
					//On a value broadcast, should the rob entry with the new value just mark as executed and empty the other fields such as sources and such??
					
					case(rob_table[i].value[2:0])
						add_trb[34:32]: begin
							rob_table[i].value <= add_trb[31:0]; //load value
							rob_table[i].exec <= 1'b1; //mark as executed
							rob_table[i].busy <= 1'b0; //not busy
						end
						mul_trb[34:32]: begin
							rob_table[i].value <= mul_trb[31:0];
							rob_table[i].exec <= 1'b1;
							rob_table[i].busy <= 1'b0;
						end
					endcase
					
					//Checking for dependent entries with source's waiting
					
					//source1 check
					case(rob_table[i].src1[2:0])
						add_trb[34:32]: begin
							rob_table[i].src1 <= add_trb[31:0];
							rob_table[i].v1 <= 1'b1; //set source value as valid
						end
						mul_trb[34:32]: begin
							rob_table[i].src1 <= mul_trb[31:0];
							rob_table[i].v1 <= 1'b1;
						end
					endcase
					//source2 check
					case(rob_table[i].src2[2:0])
						add_trb[34:32]: begin
							rob_table[i].src2 <= add_trb[31:0];
							rob_table[i].v2 <= 1'b1;
						end
						mul_trb[34:32]: begin
							rob_table[i].src2 <= mul_trb[31:0];
							rob_table[i].v2 <= 1'b1;
						end
					endcase
				end
			end
		end
	end
	
//	always_ff @(posedge clk) begin	
//		// On value broadcast - check if other entries need data from destination reg that got it's value
//		// Essentially look for dependent entries in the ROB - if found, mark related source as valid
//		// based on tag of function unit broadcast
//		
//		// Using for loop for now but may have to go back to case statements from notes
//		// Remember for loops execute fully on a clock edge
//		//rob_table[head_ptr].busy <= ~rob_table[head_ptr].exec; //entry becomes busy when it enters; surely an entry cannot be busy and executed at the same time - right?
//		if((valid_add && add_trb /*broadcast is not 0*/) || (valid_mul && mul_trb)) begin //if most
//			for(int i = 0; i < ROB_DEPTH; i++) begin
//				//Checking for associated destReg's with undefined value
//				//On a value broadcast, should the rob entry with the new value just mark as executed and empty the other fields such as sources and such??
//				
//				//Bug: need to change these case statements so they don't assign or change entries when one broadcast is 0
//				case(rob_table[i].value[2:0])
//					add_trb[34:32]: begin
//						rob_table[i].value <= add_trb[31:0]; //load value
//						rob_table[i].exec <= 1'b1; //mark as executed
//						rob_table[i].busy <= 1'b0; //not busy
//					end
//					mul_trb[34:32]: begin
//						rob_table[i].value <= mul_trb[31:0];
//						rob_table[i].exec <= 1'b1;
//						rob_table[i].busy <= 1'b0;
//					end
//				endcase
//				
//				//Checking for dependent entries with source's waiting
//				
//				//source1 check
//				case(rob_table[i].src1[2:0])
//					add_trb[34:32]: begin
//						rob_table[i].src1 <= add_trb[31:0];
//						rob_table[i].v1 <= 1'b1; //set source value as valid
//					end
//					mul_trb[34:32]: begin
//						rob_table[i].src1 <= mul_trb[31:0];
//						rob_table[i].v1 <= 1'b1;
//					end
//				endcase
//				//source2 check
//				case(rob_table[i].src2[2:0])
//					add_trb[34:32]: begin
//						rob_table[i].src2 <= add_trb[31:0];
//						rob_table[i].v2 <= 1'b1;
//					end
//					mul_trb[34:32]: begin
//						rob_table[i].src2 <= mul_trb[31:0];
//						rob_table[i].v2 <= 1'b1;
//					end
//				endcase
//			end
//		end
//	end
endmodule