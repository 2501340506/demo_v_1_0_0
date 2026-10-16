"""Generate production M4 top from the explicit M3 hardware harness."""
from pathlib import Path
import sys
out=Path(sys.argv[1]);s=(out/'tb_m3_top.sv').read_text(encoding='utf-8')
s=s.replace('module tb_m3_top;', 'module tb_m4_top;')
start=s.index(' reg [12:0] timing_pipe')
s=s[:start]+(Path(__file__).with_name('tb_m4_top_body.svh')).read_text(encoding='utf-8')
(out/'tb_m4_top.sv').write_text(s,encoding='utf-8')
