"""Selectively import the supplied new files; never apply its production patch."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
patch = Path(sys.argv[1]).read_bytes()
sections = re.split(rb'(?=^diff --git )', patch, flags=re.M)
out = root / 'diagnostics/output/disaster_port_import'
out.mkdir(parents=True, exist_ok=True)
tools = []
for section in sections:
    match = re.match(rb'diff --git a/(\S+) b/\S+\n', section)
    if not match or b'new file mode ' not in section:
        continue
    path = match[1].decode()
    if path.startswith('tools/'):
        # git decodes binary PNG blocks; strip the original tools prefix.
        tools.append(section)
    elif path in ('user_source/hdl_source/scene/hazard_layer.v',) or (
        path.startswith('diagnostics/mountain_scene/') and
        Path(path).name in ('make_hazard_vectors3.py', 'tb_m3v3_card.sv', 'tb_m3v3_sweep.sv')):
        lines = section.split(b'\n')
        body = b'\n'.join(line[1:] for line in lines if line.startswith(b'+') and not line.startswith(b'+++')) + b'\n'
        if path.endswith('/hazard_layer.v'):
            target = root / 'user_source/hdl_source/scene/hazard_layer_v3.v'
            body = body.replace(b'module hazard_layer ', b'module hazard_layer_v3 ')
        else:
            target = root / 'diagnostics/disaster_selector' / Path(path).name
            body = body.replace(b'hazard_layer #', b'hazard_layer_v3 #').replace(b'hazard_layer dut', b'hazard_layer_v3 dut')
        target.parent.mkdir(parents=True, exist_ok=True)
        assert not target.exists(), target
        target.write_bytes(body)
tool_patch = out / 'tools.patch'
tool_patch.write_bytes(b''.join(tools))
subprocess.run(['git', 'apply', '-p2', '--directory=tools/mountain_port', str(tool_patch)], cwd=root, check=True)
