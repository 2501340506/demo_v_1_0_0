"""Freeze the validated S3 bit; compare build inputs directly, never rebuild."""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
build_name, system_name, regression_name, fat32_name, paths_name = sys.argv[1:]
build = root / 'diagnostics/output' / build_name
out = root / 'releases/v0.8.0/s3-local.1'
report = build / 'TD_project/demo_Runs/phy_1'
baseline = '1c68673'

def read_text(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')

def validated(path, marker, vendor=False):
    text = read_text(path)
    if marker not in text or re.search(r'\*\* (Fatal|Error):', text):
        raise SystemExit(f'Failed/missing evidence: {path}')
    for line in text.splitlines():
        if '** Warning:' in line and not (vendor and re.search(r'vopt-(2685|2718|2121)', line)):
            raise SystemExit(f'Unexpected warning: {path}: {line}')

timing = read_text(report / 'final_timing.rpt')
setup = float(re.search(r'SWNS:\s*([-\d.]+)ns', timing)[1])
hold = float(re.search(r'HWNS:\s*([-\d.]+)ns', timing)[1])
if setup < 0 or hold < 0:
    raise SystemExit('Routed timing failed')
system = root / 'diagnostics/output' / system_name
regression = root / 'diagnostics/output' / regression_name
fat32 = root / 'diagnostics/output' / fat32_name
paths = root / 'diagnostics/output' / paths_name
validated(system / 'system.log', 'PASS cache system:', True)
validated(paths / 'paths.log', 'PASS frame paths:', True)
tests = ['tb_mode_key_control', 'tb_dual_key_event_router', 'tb_media_player_control',
         'tb_media_display_control', 'tb_key_gesture_control', 'tb_switch_mode_panel',
         'tb_pcm_test_tone', 'tb_hdmi_primitives', 'tb_hdmi_packets', 'tb_hdmi_s6_phy',
         'tb_pcm_media_tone', 'tb_media_commit_cdc', 'tb_sd_protocol', 'tb_rescan_key',
         'tb_sd_initialization', 'tb_sd_spi_pins', 'tb_flash_reset', 'tb_startup',
         'tb_uart_event_logger', 'tb_frame_cache_control', 'tb_video_alignment']
for name in tests:
    validated(regression / f'{name}.log', 'PASS ')
for case in range(42):
    validated(fat32 / f'reader{case}_gap2_mode0.log', 'PASS FAT32 reader')

project = build / 'TD_project/demo.al'
if project.read_bytes() != (root / 'TD_project/demo.al').read_bytes():
    raise SystemExit('Current project differs from build snapshot')
tree = ET.fromstring(project.read_text(encoding='utf-8').replace('UsedInP&R', 'UsedInP&amp;R'))
inputs, changed = [], []
for entry in tree.findall('./Source_Files/*/File'):
    relative = entry.attrib['Path']
    snapshot = (project.parent / relative).resolve()
    current = (root / 'TD_project' / relative).resolve()
    if snapshot.read_bytes() != current.read_bytes():
        raise SystemExit(f'Current input differs from tested build: {current}')
    name = current.relative_to(root).as_posix()
    inputs.append((name, snapshot.stat().st_size))
    old = subprocess.run(['git', 'show', f'{baseline}:{name}'], cwd=root, capture_output=True)
    # Git stores LF while the Windows checkout can use CRLF. Packaging scope
    # follows actual source changes, not checkout-only line-ending conversion.
    if old.returncode or old.stdout.replace(b'\r\n', b'\n') != snapshot.read_bytes().replace(b'\r\n', b'\n'):
        changed.append(name)
audit = build / 'timing_audit/check_timing.txt'
old_audit = root / 'diagnostics/output/four_bank_s1_attempt2/timing_audit/check_timing.txt'
if read_text(audit).split('1. checking nets')[0] != read_text(old_audit).split('1. checking nets')[0]:
    raise SystemExit('Timing audit categories changed; review before packaging')
if out.exists():
    raise SystemExit('Candidate already exists; do not overwrite')
out.mkdir(parents=True)

def copy(path, name):
    target = out / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    assert path.read_bytes() == target.read_bytes()

def text_copy(path, name):
    target = out / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('\n'.join(line.rstrip() for line in read_text(path).splitlines()) + '\n', encoding='utf-8')

copy(report / 'demo.bit', 'demo.bit')
copy(project, 'project/demo.al')
for name in changed:
    copy(build / name, 'sources/' + name)
for name in ['final_timing.rpt', 'demo_phy.area']:
    text_copy(report / name, 'reports/' + name)
text_copy(audit, 'reports/check_timing.txt')
text_copy(old_audit, 'reports/s1_check_timing.txt')
text_copy(system / 'system.log', 'evidence/system.log')
text_copy(system / 'compile.log', 'evidence/system_compile.log')
text_copy(paths / 'paths.log', 'evidence/paths.log')
text_copy(regression / 'compile.log', 'evidence/regression_compile.log')
for name in tests:
    text_copy(regression / f'{name}.log', f'evidence/regression/{name}.log')
for case in range(42):
    text_copy(fat32 / f'reader{case}_gap2_mode0.log', f'evidence/fat32/reader{case}.log')
text_copy(fat32 / 'compile.log', 'evidence/fat32/compile.log')
inventory = [f'baseline: {baseline} (v0.7.0 production RTL)',
             'candidate: v0.8.0-s3-local.1', f'build: {build_name}',
             f'bit bytes: {(out / "demo.bit").stat().st_size}',
             f'routed setup: {setup} ns; hold: {hold} ns',
             f'All {len(inputs)} project inputs and project configuration match the build snapshot byte-for-byte.',
             'Bit and changed-source copies compared byte-for-byte; text logs normalized to UTF-8 and stripped line-end whitespace.',
             'Unchanged sources are referenced through the baseline; project snapshot uses repository-relative layout.',
             f'Validation runs: {system_name}, {regression_name}, {fat32_name}, {paths_name}',
             '', 'Changed inputs copied:']
inventory += changed + ['', 'All project inputs (path, bytes):']
inventory += [f'{name}\t{size}' for name, size in inputs]
(out / 'sources.txt').write_text('\n'.join(inventory) + '\n', encoding='utf-8')
print(f'Packaged S3: {len(changed)} changed inputs, {len(inputs)} total inputs, setup={setup}, hold={hold}')
