// One bundled mailbox for normal preview and menu snapshots. The normal
// producer receives its acknowledgement even while menu pixels are visible.
module disaster_menu_descriptor(
 input clk,rst,normal_request,input [17:0] normal_descriptor,
 output reg normal_ack,
 input visible,input [1:0] focus,input [3:0] valid,input [5:0] identity,
 output reg request,output reg [31:0] descriptor,input ack,
 output display_off
);
 (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync;
 reg sent_normal;
 reg [31:0] committed;
 wire [31:0] desired={1'b0,identity,visible,focus,valid,normal_descriptor};
 assign display_off=!committed[24] && ack_sync[1]==request;
 always @(posedge clk or posedge rst)begin
  if(rst)begin ack_sync<=0;normal_ack<=0;sent_normal<=0;committed<=0;request<=0;descriptor<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(ack_sync[1]==request)begin
    normal_ack<=sent_normal;committed<=descriptor;
    if(desired!=descriptor || normal_request!=sent_normal)begin
     descriptor<=desired;sent_normal<=normal_request;request<=~request;
    end
   end
  end
 end
endmodule
