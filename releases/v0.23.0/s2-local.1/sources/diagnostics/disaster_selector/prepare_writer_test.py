from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1])
s=(root/'diagnostics/image_scaling/tb_thumbnail_loader.sv').read_text()
s=s.replace('module tb_thumbnail_loader;', 'module tb_menu_writer;')
s=s.replace('reg [31:0] pixel=0;', 'reg [31:0] pixel=0; reg menu=0,native=0;reg [1:0] slot=2;')
s=s.replace('media_thumbnail_loader dut(', 'media_thumbnail_loader #(.MENU_ENABLE(1),.NATIVE_MENU_ENABLE(1)) dut(.menu_mode(menu),.native_menu(native),')
s=s.replace('pixel=pattern(i%640,479-i/640);', 'pixel=native?pattern(i%256,191-i/256):pattern(i%640,479-i/640);')
s=s.replace('.write_addr_index(2\'d2)', '.write_addr_index(slot)')
start=s.index('  $display("PASS dual loader:')
end=s.index(' initial begin #200000000;',start)
s=s[:start]+'''  // Four independent menu slots; bottom-up 640x480 source -> 256x192.
  // Verify every sample and assert every menu write stays in its own slot.
  menu=1;
  for(integer q=0;q<4;q=q+1)begin
   slot=q;start();send_pixels(307200);done=1;@(negedge src);done=0;
   wait(completions==q+2);repeat(20)@(negedge clk);
   for(integer y=0;y<192;y=y+1)for(integer x=0;x<256;x=x+1)
    if(memory.memory[physical(1536000+q*49152+y*256+x)]!==pattern((x*5)/2,(y*5)/2))
      $fatal(1,"menu pixel slot=%0d x=%0d y=%0d got=%h expected=%h",q,x,y,
       memory.memory[physical(1536000+q*49152+y*256+x)],pattern((x*5)/2,(y*5)/2));
  end
  // Native thumbnails bypass both full-frame scaling and menu sampling.
  native=1;
  for(integer q=0;q<4;q=q+1)begin
   slot=q;start();send_pixels(49152);done=1;@(negedge src);done=0;
   wait(completions==q+6);repeat(20)@(negedge clk);
   for(integer y=0;y<192;y=y+1)for(integer x=0;x<256;x=x+1)
    if(memory.memory[physical(1536000+q*49152+y*256+x)]!==pattern(x,y))
     $fatal(1,"native menu pixel slot=%0d x=%0d y=%0d",q,x,y);
  end
  // Menu traffic must preserve the normal full/preview caches.
  for(integer y=0;y<480;y=y+1)for(integer x=0;x<640;x=x+1)
   if(memory.memory[physical(614400+y*640+x)]!==pattern(x,y))$fatal(1,"full cache overwritten");
  for(integer y=0;y<240;y=y+1)for(integer x=0;x<320;x=x+1)
   if(memory.memory[physical(1382400+y*320+x)]!==pattern(x*2,y*2))$fatal(1,"preview overwritten");
  $display("PASS menu writer: 196608 menu pixels, 384000 old cache pixels, cancel, backpressure, refresh");$finish;
 end
 always @(posedge clk)if(menu && we_app && (wa<1536000+slot*49152 || wa>=1536000+(slot+1)*49152))
  $fatal(1,"menu cache escape %0d slot %0d",wa,slot);
''' +s[end:]
s=s.replace('#200000000;', '#1000000000;')
(out/'tb_menu_writer.sv').write_text(s,encoding='utf-8')
