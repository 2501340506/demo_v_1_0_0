`timescale 1ns/1ps
module frame_fifo_write
#
(
	parameter MEM_DATA_BITS          = 32,
    parameter BURST_GATE_ENABLE = 0,
    parameter MENU_ENABLE = 0,
	parameter ADDR_BITS              = 21,
	parameter BURST_BITS             = 9,
	parameter BURST_SIZE             = 128,
	parameter WRITE_V_FLIP           = 1,      // 1: write image rows upside-down to cancel BMP bottom-up storage
	parameter FRAME_WIDTH            = 640,
	parameter FRAME_HEIGHT           = 480
)               
(
	input                            rst,                  
	input                            mem_clk,                    // external memory controller user interface clock
	input							 Sdr_init_done,
	input							 Sdr_init_ref_vld,
    input							 Sdr_busy,
	input							 App_rd_busy,
	input                            burst_permit,
    input menu_mode,
    output							 O_wr_busy,
	
	output 							 App_wr_en,
	output  [ADDR_BITS - 1:0]	 	App_wr_addr,
	/*
    output reg                       wr_burst_req,               // to external memory controller,send out a burst write request  
	output reg[BURST_BITS - 1:0]     wr_burst_len,               // to external memory controller,data length of the burst write request, not bytes 
	output reg[ADDR_BITS - 1:0]      wr_burst_addr,              // to external memory controller,base address of the burst write request 
	input                            wr_burst_data_req,          // from external memory controller,write data request ,before data 1 clock 
	input                            wr_burst_finish,            // from external memory controller,burst write finish
	*/
	input write_cancel_req,
    output reg write_cancel_ack,
	input                            write_req,                  // data write module write request,keep '1' until read_req_ack = '1'
	output reg                       write_req_ack,              // data write module write request response
	output                           write_finish,               // data write module write request finish
	input[ADDR_BITS - 1:0]           write_addr_0,               // data write module write request base address 0, used when write_addr_index = 0
	input[ADDR_BITS - 1:0]           write_addr_1,               // data write module write request base address 1, used when write_addr_index = 1
	input[ADDR_BITS - 1:0]           write_addr_2,               // data write module write request base address 1, used when write_addr_index = 2
	input[ADDR_BITS - 1:0]           write_addr_3,               // data write module write request base address 1, used when write_addr_index = 3
	input[1:0]                       write_addr_index,           // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
	input[ADDR_BITS - 1:0]           write_len,                  // data write module write request data length
	output reg                       fifo_aclr,                  // to fifo asynchronous clear
	input[9:0]                      rdusedw                     // from fifo read used words
);
localparam ONE                       = 256'd1;                   //256 bit '1'   you can use ONE[n-1:0] for n bit '1'
localparam ZERO                      = 256'd0;                   //256 bit '0'

// Vertical flip address mapping for 640x480 frame buffer.
// Input stream order remains unchanged; only SDRAM write addresses are remapped:
// stream row 0 -> memory row FRAME_HEIGHT-1, stream row 1 -> memory row FRAME_HEIGHT-2, ...
localparam [ADDR_BITS - 1:0] VFLIP_FIRST_ADDR_OFFSET = (FRAME_HEIGHT - 1) * FRAME_WIDTH;
localparam [ADDR_BITS - 1:0] VFLIP_LINE_JUMP         = (FRAME_WIDTH * 2) - 1;
localparam X_BITS                    = $clog2(FRAME_WIDTH);
localparam [X_BITS - 1:0]    VFLIP_LINE_LAST_X       = FRAME_WIDTH - 1;
// write_len is held static by every user and is a multiple of BURST_SIZE
// (a power of two), so whole bursts are counted and the remaining length is
// always at least one burst while a burst is being decided.
localparam BURST_LOG2                = $clog2(BURST_SIZE);
localparam CNT_BITS                  = ADDR_BITS - BURST_LOG2;

//write state machine code
localparam S_IDLE                    = 0;                        //idle state,waiting for write
localparam S_ACK                     = 1;                        //written request response
localparam S_CHECK_FIFO              = 2;                        //check the FIFO status, ensure that there is enough space to burst write
localparam S_WRITE_BURST             = 3;                        //begin a burst write
localparam S_WRITE_BURST_END         = 4;                        //a burst write complete
localparam S_END                     = 5;                        //a frame of data is written to complete


reg                                 write_req_d0;                //asynchronous write request, synchronize to 'mem_clk' clock domain,first beat
reg                                 write_req_d1;                //the second
reg                                 write_req_d2;                //third,Why do you need 3 ? Here's the design habit
reg[CNT_BITS - 1:0]                 write_cnt;                   //written bursts
reg[CNT_BITS - 1:0]                 target_bursts;
reg[1:0]                            write_addr_index_d0;
reg[1:0]                            write_addr_index_d1;
reg[3:0]                            state;                       //state machine
reg [ADDR_BITS - 1:0]	 App_wr_addr_r;
reg [X_BITS - 1:0]                    wr_x;                       // current x position in one input row
reg [9:0]                             rdusedw_latched;

reg [BURST_BITS - 1:0]				burst_cnt;
wire								wr_burst_finish;

reg App_wr_en_r;
reg App_wr_en_d0;

reg [1:0] cancel_sync;
wire cancel_active = cancel_sync[1];
localparam S_CANCEL = 6;
always @(posedge mem_clk or posedge rst) begin
    if (rst) cancel_sync <= 0;
    else cancel_sync <= {cancel_sync[0], write_cancel_req};
end
wire into_burst;
// Sample the asynchronous FIFO occupancy before the burst decision.  Keeping
// the wide compare local to this clocked boundary removes the direct FIFO
// pointer-to-state timing path while preserving the existing one-cycle check.
assign into_burst = (!BURST_GATE_ENABLE || burst_permit) && !Sdr_busy && !Sdr_init_ref_vld && !cancel_active && (rdusedw_latched >= BURST_SIZE && ~App_rd_busy);

reg [1:0] menu_sync;
reg menu_geometry;
always @(posedge mem_clk or posedge rst)begin
 if(rst)begin menu_sync<=0;menu_geometry<=0;end
 else begin menu_sync<={menu_sync[0],MENU_ENABLE && menu_mode};
  if(state==S_ACK)menu_geometry<=menu_sync[1];
 end
end
wire [ADDR_BITS-1:0] first_offset=menu_sync[1]?21'd48896:VFLIP_FIRST_ADDR_OFFSET;
wire [ADDR_BITS-1:0] base0=(MENU_ENABLE && menu_sync[1])?21'd1536000:write_addr_0;
wire [ADDR_BITS-1:0] base1=(MENU_ENABLE && menu_sync[1])?21'd1585152:write_addr_1;
wire [ADDR_BITS-1:0] base2=(MENU_ENABLE && menu_sync[1])?21'd1634304:write_addr_2;
wire [ADDR_BITS-1:0] base3=(MENU_ENABLE && menu_sync[1])?21'd1683456:write_addr_3;
wire [X_BITS-1:0] line_last=menu_geometry?256-1:VFLIP_LINE_LAST_X;
wire [ADDR_BITS-1:0] line_jump=menu_geometry?21'd511:VFLIP_LINE_JUMP;
wire [ADDR_BITS - 1:0] addr_step = (WRITE_V_FLIP && wr_x == line_last) ?
	(~line_jump + 1'b1) : {{(ADDR_BITS - 1){1'b0}}, 1'b1};
assign App_wr_addr = {App_wr_addr_r[ADDR_BITS - 1:0]};
//assign O_wr_busy = (state != S_IDLE || (S_IDLE && write_req_d2));
assign O_wr_busy = (state == S_WRITE_BURST || (state == S_CHECK_FIFO && into_burst));//在突发，或者将要突发，则显示busy
assign wr_burst_finish = (burst_cnt >= BURST_SIZE);
assign write_finish = (state == S_END) ? 1'b1 : 1'b0;            //write finish at state 'S_END'
assign App_wr_en = App_wr_en_d0;


always@(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		write_req_d0    <=  1'b0;
		write_req_d1    <=  1'b0;
		write_req_d2    <=  1'b0;
		write_addr_index_d0    <=  2'b00;
		write_addr_index_d1    <=  2'b00;
	end
	else
	begin
		write_req_d0    <=  write_req;
		write_req_d1    <=  write_req_d0;
		write_req_d2    <=  write_req_d1;
		write_addr_index_d0 <= write_addr_index;
		write_addr_index_d1 <= write_addr_index_d0;
	end 
end
always @(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		burst_cnt <= ZERO[BURST_BITS - 1:0];
		App_wr_addr_r <= ZERO[ADDR_BITS - 1:0];
		App_wr_en_d0 <= 1'b0;
		wr_x <= 0;
		rdusedw_latched <= 10'd0;
	end
	else begin
		rdusedw_latched <= rdusedw;
	
		if(state == S_CHECK_FIFO)
			burst_cnt <= ZERO[BURST_BITS - 1:0];
		else if(App_wr_en)
			burst_cnt <= burst_cnt + 1'b1;
		else
			burst_cnt <= burst_cnt;
		//
		if(state == S_ACK)
			begin
				wr_x <= 0;
				if(write_addr_index_d1 == 2'd0)
					App_wr_addr_r <= WRITE_V_FLIP ? (base0 + first_offset) : base0;
				else if(write_addr_index_d1 == 2'd1)
					App_wr_addr_r <= WRITE_V_FLIP ? (base1 + first_offset) : base1;
				else if(write_addr_index_d1 == 2'd2)
					App_wr_addr_r <= WRITE_V_FLIP ? (base2 + first_offset) : base2;
				else if(write_addr_index_d1 == 2'd3)
					App_wr_addr_r <= WRITE_V_FLIP ? (base3 + first_offset) : base3;
			end
		else if(App_wr_en)
			begin
				// One adder: +1 inside a row, -VFLIP_LINE_JUMP (mod 2^ADDR_BITS) at row end.
				App_wr_addr_r <= App_wr_addr_r + addr_step;
				if(WRITE_V_FLIP)
					wr_x <= (wr_x == line_last) ? {X_BITS{1'b0}} : wr_x + 1'b1;
			end
		else
			App_wr_addr_r <= App_wr_addr_r;
		//
		if(App_wr_en_r && burst_cnt + App_wr_en < BURST_SIZE)begin
            App_wr_en_d0 <= 1'b1;
        end
		else
			App_wr_en_d0 <= 1'b0;
	
	end		
end
always@(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;
        write_cancel_ack <= 0;
		
		//wr_burst_addr <= ZERO[ADDR_BITS - 1:0];
		//wr_burst_req <= 1'b0;
		App_wr_en_r <= 1'b0;
		
		write_cnt <= 0;
        target_bursts <= 0;
		fifo_aclr <= 1'b0;
		write_req_ack <= 1'b0;
		//wr_burst_len <= ZERO[BURST_BITS - 1:0];
		
		
	end
	else
        // Finish the issued burst and its registered final write before clear.
        if (cancel_active && state != S_WRITE_BURST && state != S_CANCEL &&
            !App_wr_en && !App_wr_en_r && !Sdr_busy) begin
            state <= S_CANCEL;
            fifo_aclr <= 1;
            write_req_ack <= 0;
            write_cnt <= 0;
        end else case(state)
			//idle state,waiting for write write_req_d2 == '1' goto the 'S_ACK'
			S_IDLE:
			begin
				if(write_req_d2 == 1'b1 && Sdr_init_done)
				begin
					state <= S_ACK;
				end
				write_req_ack <= 1'b0;
			end
			//'S_ACK' state completes the write request response, the FIFO reset, the address latch, and the data length latch
			S_ACK:
			begin
                // Mode crosses before the held request is acknowledged.
                // Only local, transaction-latched length drives burst completion.
                target_bursts <= (MENU_ENABLE && menu_sync[1]) ? (49152 >> BURST_LOG2) : write_len[ADDR_BITS-1:BURST_LOG2];
				//after write request revocation(write_req_d2 == '0'),goto 'S_CHECK_FIFO',write_req_ack goto '0'
				if(write_req_d2 == 1'b0)
				begin
					state <= S_CHECK_FIFO;
					fifo_aclr <= 1'b0;
					write_req_ack <= 1'b0;
				end
				else
				begin
					//write request response
					write_req_ack <= 1'b1;
					//FIFO reset
					fifo_aclr <= 1'b1;
					//select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
					/*
					if(write_addr_index_d1 == 2'd0)
						wr_burst_addr <= write_addr_0;
					else if(write_addr_index_d1 == 2'd1)
						wr_burst_addr <= write_addr_1;
					else if(write_addr_index_d1 == 2'd2)
						wr_burst_addr <= write_addr_2;
					else if(write_addr_index_d1 == 2'd3)
						wr_burst_addr <= write_addr_3;
					*/
				end
				//write data counter reset, write_cnt <= 0;
				write_cnt <= 0;
			end
			S_CHECK_FIFO:
			begin
				//if there is a write request at this time, enter the 'S_ACK' state
				if(write_req_d2 == 1'b1)
				begin
					state <= S_ACK;
				end
				//if the FIFO space is a burst write request, goto burst write state
				else if(into_burst)
				begin
					state <= S_WRITE_BURST;
					//wr_burst_len <= BURST_SIZE[BURST_BITS - 1:0];
					//wr_burst_req <= 1'b1;
					App_wr_en_r <= 1'b1;
				end
			end 
			
			S_WRITE_BURST:
			begin
				//burst finish
				if(wr_burst_finish == 1'b1)
				begin
					App_wr_en_r <= 1'b0;
					state <= S_WRITE_BURST_END;
					//write counter + burst length
					write_cnt <= write_cnt + 1'b1;
					//the next burst write address is generated
					//wr_burst_addr <= wr_burst_addr + BURST_SIZE[ADDR_BITS - 1:0];
				end     
			end
			S_WRITE_BURST_END:
			begin
				//if there is a write request at this time, enter the 'S_ACK' state
				if(write_req_d2 == 1'b1)
				begin
					state <= S_ACK;
				end
				//if the write counter value is less than the frame length, continue writing,
				//otherwise the writing is complete
				else if(write_cnt < target_bursts)
				begin
					state <= S_CHECK_FIFO;
				end
				else
				begin
					state <= S_END;
				end
			end
			S_END:
			begin
				state <= S_IDLE;
			end
            S_CANCEL: begin
                write_cancel_ack <= 1;
                if (!cancel_active) begin
                    write_cancel_ack <= 0;
                    fifo_aclr <= 0;
                    state <= S_IDLE;
                end
            end
			default:
				state <= S_IDLE;
		endcase
end
endmodule
