"""Retain old scan/reader assertions; adapt only the new unused status port."""
from pathlib import Path
import runpy,sys
root=Path(__file__).resolve().parents[2]
n=runpy.run_path(str(root/'diagnostics/publicity_mode/prepare_m2.py'))
out=Path(sys.argv[1])
for name,mod in [('tb_publicity_scan.sv','fat32_volume_scanner'),('tb_publicity_reader.sv','fat32_bmp_reader')]:
 s=(root/'diagnostics/publicity_mode'/name).read_text(encoding='utf-8')
 s=n['complete_pins'](s,mod)
 (out/name).write_text(s,encoding='utf-8')
s=(out/'tb_publicity_scan.sv').read_text(encoding='utf-8')
s=s.replace('module tb_publicity_scan #','module tb_m4_scan_status #')
s=s.replace('wire [3:0] pic,edu,voi,snd;','wire [3:0] pic,edu,voi,snd,invalid;')
s=s.replace('.voi_invalid()', '.voi_invalid(invalid)')
s=s[:s.index(' integer a,b,c,d,j,k,t;')]+'''
 initial begin
 setup();repeat(4)@(negedge clk);rst=0;
 entry(0,"VOI1    PCM",24,0,32);entry(1,"VOI2    PCM",25,3,32);
 entry(2,"VOI3    PCM",1,2,32);entry(3,"VOI4    PCM",101,2,32);
 disk[1152]=0;scan(0,0,0);if(invalid!==15)$fatal(1,"bad metadata flags %h",invalid);
 setup();disk[1024]=0;scan(0,0,0);if(invalid!==0)$fatal(1,"rescan stale invalid");
 setup();entry(0,"VOI1    PCM",24,3,32);entry(1,"VOI1    PCM",24,0,32);
 entry(2,"VOI1    PCM",24,2,32);disk[1120]=0;scan(0,1,0);
 if(invalid!==0 || vc[31:0]!=24 || vz[31:0]!=2)$fatal(1,"valid duplicate must clear error");
 setup();entry(0,"VOI2    PCM",25,2,32);entry(1,"VOI2    PCM",1,3,32);
 disk[1088]=0;scan(0,2,0);if(invalid!==0 || vz[63:32]!=2)$fatal(1,"bad duplicate replaced good");
 setup();entry(0,"VOI3    PCM",1,3,16);entry(1,"VOI4    PCM",1,3,15);
 disk[1088]=0;scan(0,0,0);if(invalid!==0)$fatal(1,"non-file marked corrupt");
 setup();entry(0,"VOI1    PCM",24,3,32);disk[1056]=0;scan(0,0,0);
 if(invalid!==1)$fatal(1,"last invalid missing");
 rst=1;repeat(2)@(negedge clk);if(invalid!==0)$fatal(1,"reset stale invalid");
 $display("PASS M4 scanner invalid: %0d scans GAP=%0d; empty/odd/cluster, clear, duplicates, attributes, reset",scenario,GAP);$finish;
 end
 initial begin #30000000;$fatal(1,"M4 scan status watchdog");end
endmodule
'''
(out/'tb_m4_scan_status.sv').write_text(s,encoding='utf-8')
