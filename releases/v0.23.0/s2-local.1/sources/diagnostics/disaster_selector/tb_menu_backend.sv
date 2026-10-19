`timescale 1ns/1ps
module tb_menu_backend;
 reg clk=0,rst=1,enter=0,confirm=0,cancel=0;always #5 clk=~clk;
 reg [1:0] focus=0;reg rdready=1,sdone=0,serror=0;
 reg [3:0] mapped=0;reg accept=0,result=0,success=1,done=0,error=0;
 reg appbusy=0,sceneready=0,commit=0,off=0;
 wire owner,ready,discard,menuwrite,scan,request,resultready,direct,visible,force_scene,exitdone,resume;
 wire [31:0] directory,selected;wire pub;wire [2:0] hazard,selectedhazard;
 wire [1:0] index,slot;wire [3:0] valid;
 disaster_menu_backend dut(.clk(clk),.rst(rst),.enter(enter),.confirm(confirm),.cancel(cancel),.focus(focus),
 .invalidate(1'b0),.native_thumb(1'b0),.application_error(1'b0),.storage_busy(1'b0),.original_app(2'd1),
 .force_target(),.rejected(),.fallback_thumbnail(),.preview_mode(),
 .parent_valid(1'b1),.parent_cluster(32'd20),.original_directory(32'd80),.original_publicity(1'b1),.original_hazard(3'd0),
 .reader_ready(rdready),.scan_done(sdone),.scan_error(serror),.mapped_valid(mapped),
 .directory_valid(6'b111100),.directory_clusters({32'd70,32'd60,32'd50,32'd40,64'd0}),
 .load_accept(accept),.load_result_valid(result),.load_success(success),.source_done(done),.source_error(error),
 .application_busy(appbusy),.scene_ready(sceneready),.display_committed(commit),.display_off(off),
 .owner(owner),.ready(ready),.discard(discard),.menu_write(menuwrite),.scan_start(scan),.directory(directory),
 .publicity(pub),.hazard(hazard),.load_request(request),.load_result_ready(resultready),.direct_load(direct),
 .load_index(index),.write_slot(slot),.valid(valid),.visible(visible),.force_scene(force_scene),
 .exit_done(exitdone),.resume(resume),.selected_directory(selected),.selected_hazard(selectedhazard));
 integer scans=0,loads=0,verifies=0;
 integer scan_timer=0,write_timer=0,verify_timer=0;
 always @(negedge clk)begin
  accept=0;result=0;done=0;error=0;
  if(scan_timer>0)begin
   scan_timer=scan_timer-1;
   if(scan_timer==0)begin mapped=directory==50?4'b1101:4'b1111;sdone=1;rdready=1;end
  end
  if(write_timer>0)begin write_timer=write_timer-1;if(write_timer==0)begin result=1;success=1;end end
  if(verify_timer>0)begin
   verify_timer=verify_timer-1;
   if(verify_timer==0)begin rdready=1;if(directory==60 && index==2)error=1;else done=1;end
  end
  if(scan)begin
   if(!owner || !rdready)$fatal(1,"scan ownership");
   scans++;sdone=0;rdready=0;scan_timer=6;
  end
  if(request)begin
   if(!menuwrite || discard || !mapped[0] || !owner)$fatal(1,"unsafe writer request");
   loads++;accept=1;write_timer=8;
  end
  if(direct)begin
   if(!discard || menuwrite || index==0)$fatal(1,"discard ownership");
   verifies++;rdready=0;verify_timer=5;
  end
 end
 task pulse_enter;@(negedge clk);enter=1;@(negedge clk);enter=0;endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;pulse_enter();wait(ready);#1;
  if(valid!==4'b1111 || scans!=5 || loads!=4 || verifies!=0)$fatal(1,"validation valid=%b scans=%0d loads=%0d verify=%0d",valid,scans,loads,verifies);
  @(negedge clk);cancel=1;@(negedge clk);cancel=0;
  wait(!visible);if(directory!=80 || !pub || hazard!=0)$fatal(1,"restore metadata");
  repeat(8)@(negedge clk);if(exitdone)$fatal(1,"early exit before display ack");
  off=1;wait(exitdone);if(!resume)$fatal(1,"cancel restart");@(negedge clk);off=0;
  pulse_enter();wait(ready);
  if(loads!=4 || scans!=6)$fatal(1,"menu cache not reused");
  focus=1;@(negedge clk);confirm=1;@(negedge clk);confirm=0;
  wait(dut.rejected);wait(ready);if(valid!=13 || !visible)$fatal(1,"later header failure escaped menu");
  focus=3;@(negedge clk);confirm=1;@(negedge clk);confirm=0;
  wait(force_scene);if(selected!=70 || selectedhazard!=4)$fatal(1,"selection identity");
  appbusy=1;repeat(5)@(negedge clk);commit=1;@(negedge clk);commit=0;appbusy=0;sceneready=1;
  wait(!visible);repeat(5)@(negedge clk);off=1;wait(exitdone);if(resume)$fatal(1,"confirm must not restore old stage");
  $display("PASS menu backend: four first-image loads only, cache reuse, later header rejection, cancel restore, confirm, frame ack");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog state=%0d",dut.state);end
endmodule
