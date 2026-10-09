"""Freeze a timing-clean S1 build and its minimal reproducibility evidence."""
from pathlib import Path
import re
import shutil
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
build_name = sys.argv[1]
build = root / 'diagnostics/output' / build_name
destination = root / 'releases/v0.8.0/s1-local.1'
report_dir = build / 'TD_project/demo_Runs/phy_1'
timing = (report_dir / 'final_timing.rpt').read_text()
setup = float(re.search(r'SWNS:\s*([-\d.]+)ns', timing)[1])
hold = float(re.search(r'HWNS:\s*([-\d.]+)ns', timing)[1])
if setup < 0 or hold < 0:
    raise SystemExit('Timing failed; no release package created')
if destination.exists():
    raise SystemExit('Candidate already exists; do not overwrite it')

project = build / 'TD_project/demo.al'
project_text = project.read_text(encoding='utf-8')
tree = ET.fromstring(project_text.replace('UsedInP&R', 'UsedInP&amp;R'))
inputs = []
for entry in tree.findall('./Source_Files/*/File'):
    relative = entry.attrib['Path']
    snapshot = (project.parent / relative).resolve()
    current = (root / 'TD_project' / relative).resolve()
    if snapshot.read_bytes() != current.read_bytes():
        raise SystemExit(f'Build source differs from current file: {relative}')
    inputs.append((current.relative_to(root).as_posix(), snapshot.stat().st_size))
if project.read_bytes() != (root / 'TD_project/demo.al').read_bytes():
    raise SystemExit('Project differs from build snapshot')

destination.mkdir(parents=True)
def copy(source, relative):
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    if source.read_bytes() != target.read_bytes():
        raise SystemExit(f'Copy differs: {target}')

copy(report_dir / 'demo.bit', 'demo.bit')
for name in ['final_timing.rpt', 'demo_phy.area']:
    copy(report_dir / name, 'reports/' + name)
copy(project, 'project/demo.al')
changed = ['user_source/hdl_source/top_tf_hdmi_audio.v',
           'user_source/hdl_source/SD/sd_card_bmp.v',
           'user_source/hdl_source/SD/media_frame_loader.v',
           'user_source/hdl_source/SD/media_frame_reader.v']
for name in changed:
    copy(build / name, 'sources/' + name)
copy(root / 'diagnostics/output/four_bank_s1_paths5/paths.log', 'evidence/paths.log')
for test in ['tb_pixel_handoff', 'tb_rescan_handoff']:
    for phase, gap in [(17, 2), (19, 16), (23, 64)]:
        name = f'{test}_{phase}_{gap}.log'
        copy(root / 'diagnostics/output/four_bank_s1_handoff4' / name, 'evidence/' + name)
for name in ['startup', 'reset']:
    copy(root / 'diagnostics/output/four_bank_s1_handoff4' / (name + '.log'), 'evidence/' + name + '.log')
inventory = ['baseline: 1c68673 (production RTL equals v0.7.0)',
             'candidate: v0.8.0-s1-local.1', 'build: ' + build_name,
             f'bit bytes: {(destination / "demo.bit").stat().st_size}',
             f'routed setup: {setup} ns; hold: {hold} ns',
             f'All {len(inputs)} project inputs and project configuration compared byte-for-byte to the build snapshot.',
             'Unchanged inputs are referenced through the baseline; only four changed/new RTL files are copied.',
             'Project snapshot refers to repository layout; it is not a standalone copied project.',
             '', 'Project inputs (path, bytes):']
inventory += [f'{name}\t{size}' for name, size in inputs]
(destination / 'sources.txt').write_text('\n'.join(inventory) + '\n', encoding='utf-8')
print(f'Packaged {destination}: setup={setup}, hold={hold}, inputs={len(inputs)}')
