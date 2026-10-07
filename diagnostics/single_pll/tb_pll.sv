`timescale 1ns/100fs
module tb_pll;
reg refclk=0,reset=1;
always #10 refclk=~refclk;
wire [4:0] c;
wire locked;
sys_pll_s3 dut(refclk,reset,locked,c[0],c[1],c[2],c[3],c[4]);
realtime prev[0:4];
realtime expected[0:4];
realtime phase1,phase4;
integer count[0:4];
genvar g;
generate for(g=0;g<5;g=g+1) begin
 always @(posedge c[g]) if(locked) begin
  if(count[g]>0 && (($realtime-prev[g]-expected[g]>0.002) || ($realtime-prev[g]-expected[g]<-0.002)))
   $fatal(1,"C%0d period %f",g,$realtime-prev[g]);
  prev[g]=$realtime;count[g]=count[g]+1;
 end
end endgenerate
always @(posedge c[1]) phase1=$realtime;
always @(posedge c[4]) phase4=$realtime;
always @(posedge c[2]) if(locked && count[2]>2) begin
 if($realtime-phase1<11.998 || $realtime-phase1>12.002) $fatal(1,"C2 phase %f",$realtime-phase1);
end
always @(posedge c[3]) if(locked && count[3]>2) begin
 #0.0001;
 if($realtime-phase4>0.002) $fatal(1,"C3/C4 phase %f",$realtime-phase4);
end
initial begin
 expected[0]=10;expected[1]=25;expected[2]=25;expected[3]=40;expected[4]=8;
 for(integer i=0;i<5;i=i+1) begin count[i]=0;prev[i]=0;end
 #100;reset=0;wait(locked);#10000;
 for(integer i=0;i<5;i=i+1) if(count[i]<100) $fatal(1,"missing clock");
 $display("PASS vendor PLL periods 10/25/25/40/8 ns, C2 +12 ns, C3/C4 aligned");$finish;
end
initial begin #1000000;$fatal(1,"PLL lock timeout");end
endmodule
