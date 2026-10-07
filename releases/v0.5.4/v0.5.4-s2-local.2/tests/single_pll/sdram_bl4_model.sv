`timescale 1ns/1ps
// Command/DQ functional SDRAM model: four banks, 2048 rows, 256 columns.
// Implements the observed JEDEC mode 0x032: sequential BL4, CL3, burst writes.
// Not a vendor timing sign-off model; tAC is modeled as 3 ns.
module sdram_bl4_model(input clk,ras,cas,we,input[1:0]ba,input[10:0]addr,
 input[3:0]dm,inout[31:0]dq);
reg [31:0] memory[0:2097151];
reg [10:0] row[0:3];reg[3:0]active=0;
reg[31:0] out_data;reg out_valid=0;
assign dq=out_valid?out_data:32'bz;
integer cycle=0,write_left=0,write_col=0,write_bank=0,read_count=0,write_count=0;
integer refresh_count=0,last_refresh=-100,mode_seen=0;
reg[31:0] pipe_data[0:6];reg[6:0]pipe_valid=0;
integer index;
always @(posedge clk) begin
 cycle=cycle+1;
 out_valid <= #3 pipe_valid[0];out_data <= #3 pipe_data[0];
 for(integer i=0;i<6;i=i+1)begin pipe_data[i]=pipe_data[i+1];pipe_valid[i]=pipe_valid[i+1];end
 pipe_valid[6]=0;
 if(write_left>0)begin
   index={row[write_bank],2'b00,8'b0}+write_bank*256+write_col;
   for(integer lane=0;lane<4;lane=lane+1)if(!dm[lane])memory[index][lane*8+:8]=dq[lane*8+:8];
   write_count=write_count+1;write_col=write_col+1;write_left=write_left-1;
   if(write_left==0)active[write_bank]=0;
 end
 case({ras,cas,we})
  3'b000:begin
   if(addr!==11'h032)$fatal(1,"unsupported SDRAM mode %h",addr);
   mode_seen=1;
  end
  3'b010:begin if(addr[10])active=0;else active[ba]=0;end
  3'b011:begin
   if(cycle-last_refresh<3)$fatal(1,"ACT before refresh recovery");
   row[ba]=addr;active[ba]=1;
  end
  3'b100:begin
   if(!mode_seen || !active[ba])$fatal(1,"WRITE without mode/active row");
   index={row[ba],ba,addr[7:0]};
   for(integer lane=0;lane<4;lane=lane+1)if(!dm[lane])memory[index][lane*8+:8]=dq[lane*8+:8];
   write_count=write_count+1;write_left=3;write_col=addr[7:0]+1;write_bank=ba;
  end
  3'b101:begin
   if(!mode_seen || !active[ba])$fatal(1,"READ without mode/active row");
   for(integer j=0;j<4;j=j+1)begin
    index={row[ba],ba,addr[7:0]}+j;
    pipe_data[j+2]=memory[index];pipe_valid[j+2]=1;
   end
   read_count=read_count+4;
   if(addr[10])active[ba]=0;
  end
  3'b001:begin
   if(active!=0 || write_left!=0 || pipe_valid!=0)$fatal(1,"refresh overlaps open row/data");
   if(cycle-last_refresh<3)$fatal(1,"refresh commands too close");
   refresh_count=refresh_count+1;last_refresh=cycle;
  end
 endcase
end
endmodule
