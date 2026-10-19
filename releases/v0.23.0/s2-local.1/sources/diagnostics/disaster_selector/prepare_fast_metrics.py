"""Generate baseline/current production-controller measurement harnesses."""
from pathlib import Path
import io
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1])
baseline = len(sys.argv) > 2 and sys.argv[2] == 'baseline'
out.mkdir(parents=True, exist_ok=False)
if baseline:
    data = subprocess.check_output(['git', 'archive', '--format=zip', '31de2b0', 'user_source'], cwd=root)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        archive.extractall(out)
    (out / 'TD_project').mkdir()
text = (root / 'diagnostics/disaster_selector/tb_selector_controller.sv').read_text()
text = text[:text.index(' integer q,n,s,before_writes')]
if baseline:
    text = text.replace('dut.menu_owner && dut.menu_preview', "1'b0")
    text = text.replace('dut.menu_native', "(1'b0)")
    text = text.replace('if(CASE_ID==16 && dut.sd_sec_read_addr>=1299 && dut.sd_sec_read_addr<=1300 && commits==0)', "if(1'b0)")
text += '''
 integer q;string prefix;
 integer ticks=0;reg mr=0,fc=0,sd=0,wd=0;
 always @(negedge clk)if(!rst)begin
  ticks++;
  if(dut.scan_start_pulse)$display("METRIC scan_start cycle=%0d reads=%0d",ticks,reads);
  if(dut.scan_result_valid && dut.scan_result_ready)$display("METRIC scan_ready cycle=%0d reads=%0d",ticks,reads);
  if(dut.source_done_now && !sd)$display("METRIC source_done cycle=%0d reads=%0d",ticks,reads);
  if(dut.write_finish_now && !wd)$display("METRIC writer_done cycle=%0d reads=%0d",ticks,reads);
  if(dut.first_image_committed && !fc)$display("METRIC first_commit cycle=%0d reads=%0d",ticks,reads);
  if(dut.menu_enter)$display("METRIC menu_enter cycle=%0d reads=%0d",ticks,reads);
  if(dut.menu_ready && !mr)$display("METRIC menu_ready cycle=%0d reads=%0d",ticks,reads);
  mr=dut.menu_ready;fc=dut.first_image_committed;sd=dut.source_done_now;wd=dut.write_finish_now;
 end
 initial begin
  prefix=$sformatf("selector%0d_",CASE_ID);
  $readmemh({prefix,"meta.hex"},meta,0,2);$readmemh({prefix,"lba.hex"},lbas,0,meta[0]-1);
  $readmemh({prefix,"bytes.hex"},disk,0,meta[0]*512-1);
  for(q=0;q<4;q++)begin bank_good[q]=0;bank_id[q]=0;bank_pixels[q]=0;end
  cycles(10);rst=0;app_ready(1);
  wait(dut.cache_valid==15);cycles(500);sw=1;wait(dut.menu_ready);cycles(10);
  $display("PASS selector metrics case=%0d reads=%0d menuWrites=%0d",CASE_ID,reads,menu_writes);$finish;
 end
 initial begin #(64'd3000000000);$fatal(1,"metrics watchdog");end
endmodule
'''
(out / 'tb_selector_controller.sv').write_text(text)
print('Prepared baseline 31de2b0' if baseline else 'Prepared current production metrics')
