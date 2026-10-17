"""Extend the real reader/cache regression with distinct BMP type bytes."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1])
s = (root/'diagnostics/output/disaster_s1_unit02/tb_m3_reload.sv').read_text(encoding='utf-8')
s = s.replace('module tb_m3_reload #', 'module tb_disaster_metadata #')
s = s.replace('wire [5:0] identity;', 'wire [7:0] displayed_kind;reg [7:0] expected_kind[0:3];\n wire [5:0] identity;')
s = s.replace('.display_kind()', '.display_kind(displayed_kind)')
s = s.replace('bank_id[wb]={dut.resource_version,dut.scan_application};', '''bank_id[wb]={dut.resource_version,dut.scan_application};
 expected_kind[wb]=dut.scan_application==1 ? 8'd0 : {4'd3,2'd0,dut.load_idx}+8'd1;''')
s = s.replace('visible=1;visible_bank=db;', '''if(displayed_kind!==expected_kind[db])$fatal(1,"type detached from displayed bank: got %h expected %h",displayed_kind,expected_kind[db]);
 visible=1;visible_bank=db;''')
s = s.replace('disk[at]="B";', 'if(k<4)begin disk[at+6]=3;disk[at+7]=k+1;end\n disk[at]="B";')
s = s.replace('PASS M3 reload', 'PASS disaster metadata and M3 reload')
(out/'tb_disaster_metadata.sv').write_text(s,encoding='utf-8')
