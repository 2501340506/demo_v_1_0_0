// A data sector is collected before replay. The streamer is permitted to
// issue its next data sector only after replay drains; FAT/audio can proceed.
module bmp_sector_buffer (
 input clk,rst,input in_valid,input [7:0] in_byte,input [31:0] in_offset,input in_done,
 output data_permit,output out_valid,input out_ready,
 output [7:0] out_byte,output reg [31:0] out_offset,output reg out_done
);
 localparam COLLECT=0,FETCH=1,PRESENT=2,FINISH=3;
 reg [1:0] state;
 reg [7:0] bytes[0:511];reg [7:0] data;
 reg [9:0] count;reg [8:0] read_pos;reg eof_seen;
 assign data_permit=state==COLLECT && count==0 && !in_valid && !eof_seen;
 assign out_valid=state==PRESENT;
 assign out_byte=data;
 always @(posedge clk) begin
  if(in_valid)bytes[in_offset[8:0]]<=in_byte;
  if(state==FETCH)data<=bytes[read_pos];
 end
 always @(posedge clk or posedge rst) begin
  if(rst)begin state<=COLLECT;count<=0;read_pos<=0;eof_seen<=0;out_offset<=0;out_done<=0;end
  else begin
   out_done<=0;
   if(in_done)eof_seen<=1;
   if(in_valid)begin
    count<=count+1'b1;
    if(in_offset[8:0]==511)state<=FETCH;
   end
   case(state)
    COLLECT:if((eof_seen || in_done) && !in_valid)begin
     if(count!=0)state<=FETCH;
     else begin out_done<=1;state<=FINISH;end
    end
    FETCH:state<=PRESENT;
    PRESENT:if(out_ready)begin
     out_offset<=out_offset+1'b1;read_pos<=read_pos+1'b1;count<=count-1'b1;
     if(count==1)begin read_pos<=0;state<=COLLECT;end
     else state<=FETCH;
    end
    default:;
   endcase
  end
 end
endmodule
