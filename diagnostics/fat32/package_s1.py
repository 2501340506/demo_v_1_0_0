"""Freeze a verified S1 build; compare source inputs and copy only changed RTL."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--build', required=True)
parser.add_argument('--candidate', default='s1-local.1')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
build = root / 'diagnostics/output' / args.build
physical = build / 'TD_project/demo_Runs/phy_1'
release = root / 'releases/v0.7.0' / args.candidate
if release.exists():
    raise SystemExit('Candidate directory already exists; use a new candidate number')
timing = (physical / 'final_timing.rpt').read_text()
setup = float(re.search(r'SWNS:\s*([-\d.]+)ns', timing)[1])
hold = float(re.search(r'HWNS:\s*([-\d.]+)ns', timing)[1])
if setup < 0 or hold < 0:
    raise SystemExit('Negative routed timing; not a candidate')
suite = root / 'diagnostics/output/fat32_s1_suite_console.log'
summary_bytes = suite.read_bytes()
summary = summary_bytes.decode('utf-16' if summary_bytes.startswith(b'\xff\xfe') else 'utf-8-sig')
if summary.count('PASS FAT32 S1 ') != 9:
    raise SystemExit('Complete nine-entry S1 regression summary is required')
project_path = root / 'TD_project/demo.al'
if project_path.read_bytes() != (build / 'TD_project/demo.al').read_bytes():
    raise SystemExit('Build project differs from current project')
project = project_path.read_text(encoding='utf-8-sig')
parsed = ET.fromstring(project.replace('UsedInP&R', 'UsedInP&amp;R'))
entries = parsed.findall('./Source_Files/*/File')
for entry in entries:
    rel = entry.attrib['Path']
    current = (root / 'TD_project' / rel).resolve()
    frozen = (build / 'TD_project' / rel).resolve()
    if current.read_bytes() != frozen.read_bytes():
        raise SystemExit(f'Build input changed: {rel}')

changed = subprocess.check_output(
    ['git', 'diff', '--name-only', 'v0.7.0-plan.1', '--', 'user_source'],
    cwd=root, text=True).splitlines()
for name in changed:
    destination = release / 'sources' / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, destination)

(release / 'project').mkdir(parents=True)
for entry in entries:
    old = entry.attrib['Path']
    relative = (root / 'TD_project' / old).resolve().relative_to(root).as_posix()
    target = release / 'sources' / relative if relative in changed else root / relative
    new = os.path.relpath(target, release / 'project').replace('\\', '/')
    project = project.replace(f'Path="{old}"', f'Path="{new}"')
(release / 'project/demo.al').write_text(project, encoding='utf-8')
shutil.copy2(physical / 'demo.bit', release / 'demo.bit')
reports = release / 'reports'
reports.mkdir()
for name in ('final_timing.rpt', 'demo_phy.area', 'settings.cfg'):
    shutil.copy2(physical / name, reports / name)
shutil.copy2(physical / f'build_{args.build}.log', reports / 'physical.log')
shutil.copy2(build / 'TD_project/demo_Runs/syn_1' / f'build_{args.build}.log', reports / 'synthesis.log')
for category in ('fat32_s0', 'fat32_s1_suite'):
    destination = release / 'evidence' / category
    destination.mkdir(parents=True)
    for source in sorted((root / 'diagnostics/output' / category).glob('*.log')):
        shutil.copy2(source, destination / source.name)
shutil.copy2(suite, release / 'evidence/s1_summary.log')
if (release / 'demo.bit').read_bytes() != (physical / 'demo.bit').read_bytes():
    raise SystemExit('Packaged bit differs from build bit')
note = (f'Build: {args.build}\nBase: v0.7.0-plan.1\n'
        f'Input files compared byte-for-byte: {len(entries)}\n'
        f'Changed source files packaged: {len(changed)}\n'
        f'Bit size: {(release / "demo.bit").stat().st_size} bytes\n'
        f'Packaged bit compared byte-for-byte: identical\n'
        f'Setup: {setup:+.3f} ns; Hold: {hold:+.3f} ns\n'
        'Board validation: pending\n')
(release / 'PACKAGE_CHECK.txt').write_text(note, encoding='utf-8')
print(note)
print(release)
