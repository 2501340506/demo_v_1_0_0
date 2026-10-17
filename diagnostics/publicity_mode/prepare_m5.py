"""Fresh M5 copies; retain all historical benches and failed runs."""
from pathlib import Path
import runpy
import sys
ROOT=Path(__file__).resolve().parents[2]
ns=runpy.run_path(str(ROOT/'diagnostics/publicity_mode/prepare_m4.py'))
out=Path(sys.argv[1])
for p in out.glob('*.sv'):
    s=p.read_text(encoding='utf-8').replace('.select_request()', ".select_request(1'b0)").replace('.select_stage()', ".select_stage(2'd0)")
    p.write_text(s,encoding='utf-8')
s=(out/'tb_m3_reload.sv').read_text(encoding='utf-8')
s=s.replace('module tb_m3_reload #(', 'module tb_m5_preview #(')
s=s[:s.index(' integer b0,d0,c0,i;')]+(ROOT/'diagnostics/publicity_mode/tb_m5_preview_body.svh').read_text(encoding='utf-8')
(out/'tb_m5_preview.sv').write_text(s,encoding='utf-8')
s=(out/'tb_m3_reload.sv').read_text(encoding='utf-8')
s=s.replace('module tb_m3_reload #(', 'module tb_m5_recovery #(')
s=s[:s.index(' integer b0,d0,c0,i;')]+(ROOT/'diagnostics/publicity_mode/tb_m5_recovery_body.svh').read_text(encoding='utf-8')
(out/'tb_m5_recovery.sv').write_text(s,encoding='utf-8')
for name in ('tb_m5_parameters.sv','tb_m5_scenario.sv','tb_m5_status.sv'):
    (out/name).write_text((ROOT/'diagnostics/publicity_mode'/name).read_text(encoding='utf-8'),encoding='utf-8')
print('Prepared M5 preview, parameters and scenario transaction tests')
runpy.run_path(str(ROOT/'diagnostics/publicity_mode/prepare_m5_pixels.py'))
