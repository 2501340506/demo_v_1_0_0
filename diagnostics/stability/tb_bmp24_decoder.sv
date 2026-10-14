`timescale 1ns/1ps
module tb_bmp24_decoder;
 parameter W=640,H=480;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,start=0,valid=0,ending=0;
 reg [31:0] size=0,off=0; reg [7:0] data=0,upstream=0;
 wire accepted,pvalid,commit,done; wire [23:0] rgb; wire [15:0] px,py; wire [2:0] err;
 integer i,count=0,done_count=0,accept_count=0,commit_count=0;
 integer bits=24,stride,total,send_size,mutation=0;
 reg [7:0] header[0:53];
 bmp24_decoder #(.EXPECTED_WIDTH(W),.EXPECTED_HEIGHT(H)) dut(
  .clk(clk),.rst(rst),.expected_width(16'd0),.expected_height(16'd0),.file_start(start),.file_size(size),.file_valid(valid),.file_byte(data),
  .file_byte_offset(off),.file_end(ending),.upstream_error(upstream),.header_accepted(accepted),
  .pixel_valid(pvalid),.pixel_rgb(rgb),.pixel_x(px),.pixel_y(py),.frame_commit(commit),
  .bmp_done(done),.bmp_error(err),.pixel_ready(1'b1),.file_ready(),
  .image_width(),.image_height(),.pixel_rgba());
 task put32(input integer p,input integer v); begin
  header[p]=v[7:0];header[p+1]=v[15:8];header[p+2]=v[23:16];header[p+3]=v[31:24];end endtask
 function [7:0] source(input integer n);
 integer pos,x,y,ch;
 begin
  if(n<54) source=header[n];
  else begin
   pos=(n-54)%stride;x=pos/(bits/8);y=(n-54)/stride;ch=pos%(bits/8);
   if(x>=W)source=8'hee;
   else case(ch)
    0:source=x;1:source=y;2:source=x+y;default:source=8'hfd;
   endcase
  end
 end endfunction
 task run_case(input integer depth,bad,cut,gap,tail);
 begin
  bits=depth;mutation=bad;stride=((W*(bits/8)+3)/4)*4;total=54+stride*H;
  for(i=0;i<54;i=i+1)header[i]=0;
  header[0]="B";header[1]="M";put32(2,total+tail);put32(10,54);put32(14,40);
  put32(18,W);put32(22,H);header[26]=1;header[28]=bits;
  case(bad)
   1:header[0]=0;2:put32(18,W+1);3:header[26]=2;4:header[28]=16;
   5:put32(30,1);6:put32(10,53);7:put32(14,12);9:put32(2,total-1);
  endcase
  size=total+tail;if(bad==8)size=total-1;
  count=0;done_count=0;accept_count=0;commit_count=0;
  @(negedge clk);start=1;@(negedge clk);start=0;
  send_size=total+tail-cut;
  for(i=0;i<send_size;i=i+1)begin
   off=i;data=source(i);valid=1;ending=(i==send_size-1);
   @(negedge clk);valid=0;ending=0;
   if(gap && i%7==0) repeat(2)@(negedge clk);
  end
  repeat(5)@(negedge clk);
  if(bad!=0)begin
   if(err!=1||count!=0||done_count||commit_count)$fatal(1,"header rejection %0d",bad);
  end else if(cut!=0)begin
   if(err!=3||done_count||commit_count)$fatal(1,"truncation");
  end else if(count!=W*H||done_count!=1||commit_count!=1||accept_count!=1||err!=0)
   $fatal(1,"normal depth=%0d pixels=%0d done=%0d err=%0d",bits,count,done_count,err);
  $display("PASS decoder W=%0d H=%0d depth=%0d bad=%0d cut=%0d gap=%0d tail=%0d",W,H,bits,bad,cut,gap,tail);
 end endtask
 task abort_case;
 begin
  count=0;done_count=0;commit_count=0;accept_count=0;
  @(negedge clk);start=1;@(negedge clk);start=0;
  for(i=0;i<58;i=i+1)begin
   off=i;data=source(i);valid=1;@(negedge clk);
  end
  valid=0;upstream=8'd1;@(negedge clk);upstream=0;
  // Late end and bytes must not turn an aborted file into a successful frame.
  ending=1;valid=1;repeat(3)@(negedge clk);ending=0;valid=0;
  repeat(3)@(negedge clk);
  if(err!=2||done_count||commit_count)$fatal(1,"upstream abort");
  $display("PASS decoder upstream abort");
 end endtask
 integer expected_x,expected_y;
 reg [7:0] eb,eg,er;
 always @(posedge clk)begin
  if(accepted)accept_count=accept_count+1;
  if(done)done_count=done_count+1;
  if(commit)commit_count=commit_count+1;
  if(pvalid)begin
   expected_x=count%W;expected_y=count/W;eb=expected_x;eg=expected_y;er=expected_x+expected_y;
   if(rgb!=={er,eg,eb}||px!=expected_x||py!=H-1-expected_y)
    $fatal(1,"pixel %0d rgb=%h xy=%0d,%0d",count,rgb,px,py);
   count=count+1;
  end
 end
 initial begin
  repeat(3)@(negedge clk);rst=0;
  run_case(24,0,0,0,0);run_case(32,0,0,1,0);
  run_case(24,0,0,1,11);run_case(24,0,2,0,0);
  run_case(24,1,0,0,0);run_case(24,2,0,0,0);run_case(24,3,0,0,0);
  run_case(24,4,0,0,0);run_case(24,5,0,0,0);run_case(24,6,0,0,0);
  run_case(24,7,0,0,0);run_case(24,8,0,0,0);run_case(24,9,0,0,0);run_case(24,0,0,0,0);
  abort_case();run_case(24,0,0,0,0);
  $finish;
 end
 initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
