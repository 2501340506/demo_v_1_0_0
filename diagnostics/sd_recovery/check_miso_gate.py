"""Exercise a routed identity LUT with vendor models (MISO by default)."""
from pathlib import Path
import argparse, re, subprocess

p = argparse.ArgumentParser()
p.add_argument('netlist', type=Path)
p.add_argument('run_name')
p.add_argument('--expect-zero', action='store_true')
p.add_argument('--target', default='sd_card_bmp_m0/sd_card_top_m0/MISO_delay_top')
p.add_argument('--input-net', default='sd_miso_dup_1')
p.add_argument('--label', default='MISO')
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
out = root / 'diagnostics/output' / a.run_name
out.mkdir(parents=True, exist_ok=False)
text = a.netlist.read_text()
target = a.target
def compact(value):
    return re.sub(r'\s+', '', value)
selected = []
for m in re.finditer(r'EG_PHY_LSLICE\s*#\((.*?)\)\s+\\\S+\s+\((.*?)\);', text, re.S):
    ports = dict(re.findall(r'\.(\w+)\(([^)]*)\)', m[2]))
    if target in compact(ports.get('f', '')):
        selected.append((m[1], ports))
assert len(selected) == 1, f'Expected one physical LUT driver for {target}'
params, ports = selected[0]
f_bits = ports['f'].strip('{}').split(',')
out_bit = len(f_bits) - 1 - next(i for i, s in enumerate(f_bits) if target in compact(s))
connections = []
for port, value in ports.items():
    if port in ('f', 'q', 'fx', 'fco', 'fcx'):
        connections.append(f'.{port}(result)' if port == 'f' else f'.{port}()')
    else:
        bits = value.strip('{}').split(',')
        values = ['miso' if a.input_net in compact(b) else "1'b0" for b in bits]
        connections.append(f'.{port}({"{" + ",".join(values) + "}"})')
expected = "1'b0" if a.expect_zero else 'miso'
bench = f'''`timescale 1ns/1ps
module tb_miso_gate;
reg miso=0;
wire [1:0] result;
EG_PHY_LSLICE #({params}) dut({','.join(connections)});
initial begin
 #1000;
 repeat(4)begin
  miso=0;#10;if(result[{out_bit}]!=={expected})$fatal(1,"MISO low mismatch");
  miso=1;#10;if(result[{out_bit}]!=={expected})$fatal(1,"MISO high mismatch");
 end
 $display("PASS routed {a.label} {'constant-zero negative control' if a.expect_zero else 'identity 0/1'}");$finish;
end
endmodule
'''
(out / 'tb_miso_gate.v').write_text(bench)
sim = Path('D:/modelsim/win64')
lib = (out / 'work').as_posix()
def run(exe, args, log):
    with (out / log).open('w') as f:
        r = subprocess.run([str(sim / exe), *args], stdout=f, stderr=subprocess.STDOUT)
    assert r.returncode == 0, log
run('vlib.exe', [lib], 'library.log')
vendor = Path('D:/TD/anlogic/TD6.2.1/sim_release')
sources = list((vendor/'eg4').glob('*.v')) + list((vendor/'common').glob('*.v'))
run('vlog.exe', ['-work', lib, *[s.as_posix() for s in sources]], 'vendor_compile.log')
run('vlog.exe', ['-sv', '-work', lib, (out/'tb_miso_gate.v').as_posix()], 'compile.log')
run('vsim.exe', ['-c', '-quiet', '-lib', lib, 'tb_miso_gate', 'glbl', '-l', (out/'sim.log').as_posix(), '-do', 'run -all; quit -f'], 'console.log')
result = (out/'sim.log').read_text()
assert f'PASS routed {a.label}' in result and not re.search(r'\*\* (Fatal|Error):', result), result[-2000:]
print(result[-900:])
