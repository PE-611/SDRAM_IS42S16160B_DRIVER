///////////////////////////////////////////////////////////
// Name File : main.v 												//
// Autor : Dyomkin Pavel Mikhailovich 							//
// Company : FLEXLAB													//
// Description : Test system (shift_reg/driver)			  	//
// Start design : 11.08.2022 										//
// Last revision : 15.08.2022 									//
///////////////////////////////////////////////////////////



module SDRAM_IS42S16160B_DRIVER( input SDRAM_CLK_IN,  start_write, start_read, reset,
											input [12:0] ADDR, 
											input [1:0]  BANK,

											output reg	[12:0]	DRAM_ADDR,
											output reg	[1:0]		DRAM_BA,
										//	output reg				DRAM_CAS_N,
											output reg				DRAM_CKE,
											output reg		 		DRAM_CLK,
											output reg				DRAM_CLK_SHIFT,
										//	output reg	    		DRAM_CS_N,
											output reg  [1:0]		DRAM_DQM,
										//	output reg       		DRAM_RAS_N,
										//	output reg       		DRAM_WE_N,
											output reg 	[3:0] 	DRAM_CMD,		//DRAM_CS_N, DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N
											output reg				process_flg,	//PROCESS FLAG IS HERE!
											inout       [15:0]	DRAM_DQ
										 );
										 





parameter time_200_us = 50;	// debug								  //more tackts for > 200us
parameter q_AREF_for_init				= 8;
parameter MRS_DATA						= 12'b000_1_00_010_1_000; // mode register set
parameter trc								= 10;  						  // Trc time, for simplicity Trc = Trp = Tmrd, because Trc > Trp > Tmrd
parameter trp								= 3;							  // Trp = Trc in datasheet
parameter CAS_latency 					= 3;							  // 2 or 3


reg [7:0] state;	
reg [7:0] next_state;
//reg [7:0] state_cnt;



localparam IDLE 							= 8'd0;
localparam MRS								= 8'd1;
localparam ACTIVATE_ROW					= 8'd2;
localparam REFRESH						= 8'd3;
localparam READ							= 8'd4;
localparam WRITE							= 8'd5;
localparam PRECHARGE						= 8'd6;
localparam NOP							  	= 8'd7;
										 
										 
										 
										 
localparam CMD_DESL  					= 4'b1_1_1_1; // device deselect
localparam CMD_NOP   					= 4'b0_1_1_1; // no operation
localparam CMD_BST   					= 4'b0_1_1_0; // burst stop
localparam CMD_READ  					= 4'b0_1_0_1; // read							DRAM_ADDR[10] functional bit 
localparam CMD_WRITE 					= 4'b0_1_0_0; // write
localparam CMD_ACT   					= 4'b0_0_1_1; // bank activate
localparam CMD_PRE   					= 4'b0_0_1_0; // precharge select bank
localparam CMD_REF   					= 4'b0_0_0_1; // CBR auto-refresh
localparam CMD_MRS   					= 4'b0_0_0_0; // Mode register set




parameter tREF       				= 64;    // ms
parameter quantity_autorefresh 	= 8192;  // refresh counter (cycle refresh)
parameter tCK        				= 7;     // clk period 7 ns (for calcul refresh interval)


parameter REFRESH_TIME	= (((tREF * 1_000_000) / quantity_autorefresh) / tCK); // need 64 ms
										 
										 
//reg process_flg; This flg in initialization I/O

reg [12:0] cnt_timer;
reg [16:0] cnt_autorefresh;	// debug				/// UDALENIE POSLE OTLADKI!!!!!!!!!!!

reg self_refresh;

reg flg_init;

reg [4:0]  Trc;
reg [4:0]  CAS;
	




initial begin

	DRAM_CKE 						<= 1'b1;
	DRAM_CLK_SHIFT 				<= 1'b0;
	DRAM_CLK 						<= 1'b0;
	
	cnt_timer	 					<= 24'd0;
	flg_init 						<= 1'b0;
	cnt_autorefresh			 	<= 16'd0;
	
	DRAM_CMD							<= 4'b0_1_1_1;
	DRAM_ADDR 						<= 12'd0;
	DRAM_BA 							<= 1'b0;
	DRAM_DQM 						<= 1'b0;
	
	Trc								<= 4'd0;
	CAS								<= 4'd0;
	
	process_flg 					<= 1'b1;
	self_refresh 					<= 1'b0;
	
	
	
	
	
	
end




always @* 	
		
		case (state)
			
			IDLE:
						
				
				if ((cnt_timer >= time_200_us && flg_init == 1'b0) || (self_refresh == 1'b1 && flg_init == 1'b1)) begin
					next_state <= PRECHARGE;
				end
								
				else if (start_write == 1'b0 || start_read == 1'b0) begin
					next_state <= ACTIVATE_ROW;
				end
								
				else begin
					next_state <= IDLE;
				end

				
			NOP:
			
				
				if (Trc >= trc && cnt_autorefresh >= q_AREF_for_init && flg_init == 1'b0) begin
					next_state <= MRS;
				end
				
				
				else if (Trc >= trc && cnt_autorefresh < quantity_autorefresh && flg_init == 1'b0) begin
					next_state <= REFRESH;
				end
				
				else if (Trc >= trc && cnt_autorefresh < quantity_autorefresh && self_refresh == 1'b1) begin
					next_state <= REFRESH;
				end
				
//				else if (flg_init == 1'b1 && process_flg == 1'b0 && start_write == 1'b0) begin
//					next_state <= WRITE;
//				end
//				
//				else if (flg_init == 1'b1 && process_flg == 1'b0 && start_read == 1'b0) begin
//					next_state <= READ;
//				end
				
				
				
				else if (Trc < trc) begin
					next_state <= NOP;
				end
				
				else begin
					next_state <= IDLE;
				end
				
			PRECHARGE:
						
				
				if (state == PRECHARGE) begin
					next_state <= NOP;
				end
				
								
				else begin
					next_state <= PRECHARGE;
				end
			
			REFRESH:
						
				
				if (state == REFRESH) begin
					next_state <= NOP;
				end
				
								
				else begin
					next_state <= REFRESH;
				end
				
			MRS:
						
				
				if (state == MRS) begin
					next_state <= NOP;
				end
				
								
				else begin
					next_state <= MRS;
				end
			
				
			ACTIVATE_ROW:
				
				
				if (state == ACTIVATE_ROW) begin
					next_state <= NOP;
				end	
				
							
				else begin
					next_state <= ACTIVATE_ROW;
				end
				
			READ:
						
				
				if (state == READ) begin
					next_state <= IDLE;
				end
				
							
				else begin
					next_state <= READ;
				end
				
			WRITE:
						
				
				if (state == WRITE) begin
					next_state <= IDLE;
				end
				
							
				else begin
					next_state <= WRITE;
				end
				
				
			default:
				next_state <= IDLE;
		
		endcase
		
		
always @(posedge DRAM_CLK_SHIFT) begin
	
	cnt_timer <= cnt_timer + 1'b1;
	DRAM_CKE <= 1'b1;
	
	

	
	
	if (state == IDLE) begin
		DRAM_DQM <= 1'b0;
		DRAM_CMD <= CMD_NOP;
		process_flg <= 1'b0;
	end
	
	if (state == PRECHARGE) begin
		process_flg <= 1'b1;
	
		DRAM_ADDR 	<= 12'b001000000000;
		DRAM_BA		<= 1'b00;
		DRAM_CMD  	<= CMD_PRE;
	end
		
	if (state == NOP) begin
		Trc <= Trc + 1'b1;
		DRAM_CMD <= CMD_NOP;
	end
	
	if (state != NOP) begin
		Trc <= 1'b0;
	end
	
	if (state == REFRESH) begin
		cnt_autorefresh <= cnt_autorefresh + 1'b1;
		DRAM_CMD <= CMD_REF;
	end
	

	if (state == MRS) begin
		DRAM_CMD  						<= CMD_MRS;
		DRAM_ADDR 						<= MRS_DATA;
		cnt_autorefresh 				<= 16'd0;
		DRAM_BA							<= 1'b00;
	end
		
	
	if (Trc == trc) begin
		Trc <= 1'b0;
	end
	
	if (cnt_timer >= REFRESH_TIME || self_refresh == 1'b1) begin
		cnt_timer <= 24'd0;
		self_refresh <= 1'b1;
		process_flg <= 1'b1;
	end
	
	if (cnt_timer == time_200_us + 110) begin								// 110 is quantity tacts for initialization SDRAM
		flg_init <= 1'b1;
	end
	
	if (cnt_timer < time_200_us + 1 && flg_init == 1'b0) begin		// +1 takt chtob process_flg ne provalivalsa poka flg_init ne stanet 1
		process_flg <= 1'b1;
	end
	
	if (Trc == trc && flg_init == 1'b1)  begin   
		self_refresh <= 1'b0;
	end

	
end	




always @(posedge DRAM_CLK_SHIFT or negedge reset) begin 
	
	
	if(!reset) begin
		state <= IDLE;
	end
	
	else begin
		state <= next_state;
	end
end	


always @(posedge SDRAM_CLK_IN) begin
		DRAM_CLK <= ~DRAM_CLK;
end

always @(negedge SDRAM_CLK_IN) begin
		DRAM_CLK_SHIFT <= ~DRAM_CLK_SHIFT;
end

	
	
endmodule

									
										 
