module rs_tb();
    //Inputs
    logic clk, rst;
    logic [74:0] i1, i2;
    //Outputs
    logic [1:0] add_done, mul_done, ld_done, st_done;
    logic [34:0] trb;

    res_station dut(clk, rst, i1, i2, add_done, mul_done,
                         ld_done, st_done, trb);

    always begin
        clk <= 1; #5; clk <= 0; #5;
    end
    initial begin
        rst <= 1; #11; rst <= 0;
    end

    //reservation station resource IDs
    localparam a0 = 3'b000; localparam a1 = 3'b001;
    localparam m0 = 3'b010; localparam m1 = 3'b011;
    localparam ld0 = 3'b100; localparam ld1 = 3'b101;
    localparam st0 = 3'b110; localparam st1 = 3'b111;

    logic [35:0] i1source1, i1source2, i2source1, i2source2;
    //drive instructions i1/2
    initial begin
        i1source1 = {1'b1, 3'bx, 32'd1}; i1source2 = {1'b1, 3'bx, 32'd2};
        i2source1 = {1'b1, 3'bx, 32'd3}; i2source2 = {1'b1, 3'bx, 32'd4};
        i1 = {a0, i1source1, i1source2};
        i2 = {m1, i2source1, i2source2};
		  #40;
		  i1 = 'x;
		  i2 = 'x;
    end
    always_comb begin
        if(!dut.add_busy) begin
            $display("operands A, B: %h, %h yield result %h", dut.add_operandA, dut.add_operandB, 
                        dut.add_result);
        end
    end
endmodule

//Reservation Station design
module res_station #(parameter NUM_RS = 8)
						(input logic clk, rst,
						 //[RS_ID<3-bits>, Source(1,2)<valid - 1 bit , tag - 3 (for 8 RS), value - 32>]
						 input logic [74:0] i1, i2,
						 output logic [NUM_RS/4-1:0] add_done,
						 output logic [NUM_RS/4-1:0] mul_done,
						 output logic [NUM_RS/4-1:0] ld_done,
						 output logic [NUM_RS/4-1:0] st_done,
						 output logic [34:0] tag_result_broadcast /*should go to (RAT) register file as well to update*/);
	
	//**Need to separate tag result for both adder and multiplier in case of same clock cycle finish**
	
	//reservation station resource IDs
	localparam a0 = 3'b000; localparam a1 = 3'b001;
	localparam m0 = 3'b010; localparam m1 = 3'b011;
	localparam ld0 = 3'b100; localparam ld1 = 3'b101;
	localparam st0 = 3'b110; localparam st1 = 3'b111;
	
	//RS units
	logic [74:0] RS_ADD [NUM_RS/4-1:0];
	logic [74:0] RS_MUL [NUM_RS/4-1:0];
	logic [74:0] RS_LD [NUM_RS/4-1:0];
	logic [74:0] RS_ST [NUM_RS/4-1:0];

	//logic rs_status[0:NUM_RS-1];	
	
	//fu enable signals
	logic add_busy, mul_busy; //fu status output
	logic rst_add, rst_mul;
	logic add_ena, mul_ena;
	logic valid_add, valid_mul;
	logic [31:0] add_operandA, add_operandB, add_result /*add fu out*/;
	logic [31:0] mul_operandA, mul_operandB, mul_result /*mul fu out*/;
	
	//Instantiate adder and multiplier
	add adder(clk, rst_add, add_ena, add_operandA, 
			 add_operandB, add_result, add_busy, valid_add);
	mul multiplier(clk, rst_mul, mul_ena, mul_operandA, 
			 mul_operandB, mul_result, mul_busy, valid_mul);
	
	// Instructions are dispatched on the posedge so synchronize the RS
	// to posedge

	initial begin
		//no clue why this wasn't working in the always block but fine, works here
		rst_add <= 1'b1; rst_mul <= 1'b1;
		#11;
		rst_add <= 1'b0; rst_mul <= 1'b0;
	end

	always_ff @(posedge clk) begin
		if(rst) begin
			//Initialize Reservation Stations
			RS_ADD[0] <= {a0, 72'b0};
			RS_ADD[1] <= {a1, 72'b0};
			
			RS_MUL[0] <= {m0, 72'b0};
			RS_MUL[1] <= {m1, 72'b0};

			RS_LD[0] <= {ld0, 72'b0};
			RS_LD[1] <= {ld1, 72'b0};
			
			RS_ST[0] <= {st0, 72'b0};
			RS_ST[1] <= {st1, 72'b0};
			
			//Reset all output flags to done to the dispatch unit
			add_done <= 2'b11; mul_done <= 2'b11;
			ld_done <= 2'b11;	st_done <= 2'b11;
			add_ena <= 1'b0; mul_ena <= 1'b0;
			add_operandA <= '0; add_operandB <= '0;
			mul_operandA <= '0; mul_operandB <= '0;
			
			tag_result_broadcast <= 35'bx; //making it undefined
		end else begin
			//can use the instruction rsid to determine the rs
			//[74:0] I1 AND I2 BIT WIDTH REFERENCE FIELDS - IMPORTANT FOR UNDERSTANDING SUBSEQUENT ASSIGNMENTS
			//[74:72] - RSID
			//[71:36] - source 1;[71] - valid; [70:68] - tag; [67:36] - value
			//[35:0] - source 2;[35] - valid; [34:32] - tag; [31:0] - value
			
			////////////////////////////////////////////////////////////
			//////						INSTRUCTION 1						//////
			////////////////////////////////////////////////////////////
			case (i1[74:72 /*I1 RSID*/])
				a0: begin
					RS_ADD[0] <= i1;
					add_done[0] <= 1'b0; // send rs status is busy to du
				end
				a1: begin
					RS_ADD[1] <= i1;
					add_done[1] <= 1'b0;
				end
				m0: begin
					RS_MUL[0] <= i1;
					mul_done[0] <= 1'b0;
				end
				m1: begin
					RS_MUL[1] <= i1;
					mul_done[1] <= 1'b0;
				end
				// Loads and Stores - not sure if this is how it'll look
				//- not implemented yet
				ld0: RS_LD[0] <= i1;
				ld1: RS_LD[1] <= i1;
				st0: RS_ST[0] <= i1;
				st1: RS_ST[1] <= i1;
				default: begin //Illegal i1
					//stuff
				end
			endcase
			
			////////////////////////////////////////////////////////////
			//////						INSTRUCTION 2						//////
			////////////////////////////////////////////////////////////
			case (i2[74:72 /*I1 RSID*/])
				a0: begin
					RS_ADD[0] <= i2;
					add_done[0] <= 1'b0; // send rs status is busy to du
				end
				a1: begin
					RS_ADD[1] <= i2;
					add_done[1] <= 1'b0;
				end
				m0: begin
					RS_MUL[0] <= i2;
					mul_done[0] <= 1'b0;
				end
				m1: begin
					RS_MUL[1] <= i2;
					mul_done[1] <= 1'b0;
				end
				//
				ld0: RS_LD[0] <= i2;
				ld1: RS_LD[1] <= i2;
				st0: RS_ST[0] <= i2;
				st1: RS_ST[1] <= i2;
				default: begin //Illegal i2
					//stuff
				end
			endcase
				
			//Function unit instruction dispatch
			
			//Only enable function units when there is an instruction waiting in an RS
			//Only load new operands when previous are done
			if(RS_ADD[0][71:0] != '0 || RS_ADD[1][71:0] != '0)
				add_ena <= 1'b1;
			else begin
				if(!add_busy)
					add_ena <= 1'b0;
			end
			if(RS_MUL[0][71:0] != '0 || RS_MUL[1][71:0] != '0)
				mul_ena <= 1'b1;
			else begin
				if(!mul_busy)
					mul_ena <= 1'b0;
			end
			
			//Add dispatch
			//Prioritize dispatching from RS_ADD[0] if isn't empty
			if(RS_ADD[0][71:0] != '0) begin //exclude the MSB 3 bits as they are the RSIDs, just check to see if RS entry is empty
				if(!add_busy) begin
					add_operandA <= RS_ADD[0][67:36]; add_operandB <= RS_ADD[0][31:0]; //Send reservation station values into adder
					add_done[0] <= 1'b1; //mark rs a0 available
					RS_ADD[0] <= {a0, 72'b0};
					tag_result_broadcast <= (valid_add) ? {RS_ADD[0][74:72], add_result}: 35'bx;
				end
			end else if (RS_ADD[1][71:0] != '0) begin
				if(!add_busy) begin
					add_operandA <= RS_ADD[1][67:36]; add_operandB <= RS_ADD[1][31:0];
					add_done[1] <= 1'b1;
					RS_ADD[1] <= {a1, 72'b0};
					tag_result_broadcast <= (valid_add) ? {RS_ADD[1][74:72], add_result}: 35'bx;
				end
			end
				
			//Mul dispatch
			//Prioritize RS_MUL[0] if not empty
			if(RS_MUL[0][71:0] != '0) begin
				if(!mul_busy) begin
					mul_operandA <= RS_MUL[0][67:36]; mul_operandB <= RS_MUL[0][31:0];
					mul_done[0] <= 1'b1;
					RS_MUL[0] <= {m0, 72'b0};
					tag_result_broadcast <= (valid_mul) ? {RS_MUL[0][74:72], mul_result}: 35'bx;
				end
			end else if (RS_MUL[1][71:0] != '0) begin
				if(!mul_busy) begin
					mul_operandA <= RS_MUL[1][67:36]; mul_operandB <= RS_MUL[1][31:0];
					mul_done[1] <= 1'b1;
					RS_MUL[1] <= {m1, 72'b0};
					tag_result_broadcast <= (valid_mul) ? {RS_MUL[1][74:72], mul_result}: 35'bx;
				end
			end
			
			//Block to look for tag_result matches in Reservation Stations (OTHER THAN ITSELF!)
			//when tag_result_broadcast has a value
			//If the tag is in one of the sources already waiting in the RS - then match and set the broadcasted result
			if(valid_add || valid_mul) begin
				case(tag_result_broadcast[34:32]) //should not check against itself ex - add0 tag shouldn't check for add0 match - bug, needs fixing
					/*ADD RS CHECKS*/
					RS_ADD[0][70:68]: begin //Source 1 tag
						//assign the new broadcasted value to the RS
						RS_ADD[0][71:36] <= {1'b1 /*valid*/, 3'bx /*no more tag*/, tag_result_broadcast[31:0] /*value*/};
					end
					RS_ADD[0][34:32]: begin //Source 2 tag
						RS_ADD[0][35:0] <= {1'b1, 3'bx /*no more tag*/, tag_result_broadcast[31:0]};
					end
					RS_ADD[1][70:68]: begin
						RS_ADD[1][71:36] <= {1'b1, 3'bx, tag_result_broadcast[31:0]};
					end
					RS_ADD[1][34:32]: begin
						RS_ADD[1][35:0] <= {1'b1, 3'bx, tag_result_broadcast[31:0]};
					end
					
					/*MULTIPLICATION RS CHECKS*/
					RS_MUL[0][70:68]: begin
						RS_MUL[0][71:36] <= {1'b1, 3'bx, tag_result_broadcast[31:0]};
					end
					RS_MUL[0][34:32]:	begin
						RS_MUL[0][35:0] <= {1'b1, 3'bx, tag_result_broadcast[31:0]};
					end
					RS_MUL[1][70:68]: begin
						RS_MUL[1][71:36] <= {1'b1, 3'bx, tag_result_broadcast[31:0]};
					end
					RS_MUL[1][34:32]:	begin
						RS_MUL[1][35:0] <= {1'b1, 3'bx, tag_result_broadcast[31:0]};
					end
					
					// Loads and Stores - not sure if this is how it'll look
					//- not implemented yet
					RS_LD[0][70:68]:	begin
					end
					RS_LD[0][34:32]:	begin
					end
					RS_LD[1][70:68]:	begin
					end
					RS_LD[1][34:32]:	begin
					end
					RS_ST[0][70:68]:	begin
					end
					RS_ST[0][34:32]:	begin
					end
					RS_ST[1][70:68]:	begin
					end
					RS_ST[1][34:32]:	begin
					end
					default: begin
						//stuff
					end
				endcase
			end			
		end
	end
endmodule