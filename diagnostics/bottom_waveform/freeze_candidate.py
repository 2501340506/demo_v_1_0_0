"""Freeze only a timing-clean waveform candidate; no device writes or hashes."""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT/'diagnostics/output/bottom_wave_assets01'
TARGET = ROOT/'releases/v0.20.0/s1-local.1'


def read_log(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def copy(source, relative):
    dest = TARGET/relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)
    assert dest.read_bytes() == source.read_bytes()


def main(build_name):
    build = ROOT/'diagnostics/output'/build_name
    phy = build/'TD_project/demo_Runs/phy_1'
    timing = (phy/'final_timing.rpt').read_text(errors='replace')
    metrics = {key: float(re.search(key+r':\s*([-\d.]+)ns', timing)[1])
               for key in ('SWNS', 'HWNS', 'STNS', 'HTNS')}
    assert metrics['SWNS'] > 0 and metrics['HWNS'] > 0
    assert metrics['STNS'] == metrics['HTNS'] == 0
    assert not TARGET.exists(), 'Candidate is immutable; use a new number'
    for run in ('syn_1', 'phy_1'):
        log = read_log(build/f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        assert not re.search(r'\bERROR:', log)
        if run == 'phy_1':
            assert 'Generate bitstream completely' in log
    assert (build/'timing_audit/exceptions.timing').exists()
    # Check the complete implementation snapshot, then freeze only changed files.
    checked = []
    for source in (build/'user_source').rglob('*'):
        if source.is_file():
            relative = source.relative_to(build)
            assert source.read_bytes() == (ROOT/relative).read_bytes(), str(relative)
            checked.append(str(relative))
    changed = subprocess.check_output(['git', 'diff', '--name-only', '147ef7d', 'HEAD'],
                                     cwd=ROOT, text=True, encoding='utf-8').splitlines()
    production = [p for p in changed if p.startswith('user_source/')]
    copy(phy/'demo.bit', 'demo.bit')
    for p in production:
        copy(ROOT/p, 'sources/'+p)
    copy(ROOT/'tools/publicity/geohazard_basics/make_inputs.py',
         'sources/tools/publicity/geohazard_basics/make_inputs.py')
    copy(build/'TD_project/demo.al', 'reproduce/demo.al')
    copy(ROOT/'diagnostics/run_td_build.ps1', 'reproduce/run_td_build.ps1')
    for name in ('final_timing.rpt', 'demo_phy.area', 'settings.cfg', f'build_{build_name}.log'):
        copy(phy/name, 'reports/'+name)
    for name in ('demo_gate.area', 'settings.cfg', f'build_{build_name}.log'):
        copy(build/'TD_project/demo_Runs/syn_1'/name, 'reports/synthesis/'+name)
    for name in ('audit.timing', 'check_timing.txt', 'exceptions.timing', 'sw3_sync.timing',
                 'console.log', 'exceptions.log', 'audit.tcl', 'exceptions.tcl', 'warning_review.json'):
        copy(build/'timing_audit'/name, 'reports/audit/'+name)
    copy(ROOT/'user_source/constraints_source/timing.sdc', 'reports/timing.sdc')
    (TARGET/'reports/source_check.json').write_text(json.dumps({'method': 'full byte comparison', 'files': checked}, indent=2)+'\n', encoding='utf-8')
    tests = []
    for run in ('bottom_wave_unit01', 'bottom_wave_integration01', 'bottom_wave_m5', 'bottom_wave_m4'):
        folder = ROOT/'diagnostics/output'/run
        for source in folder.glob('tb_*.log'):
            if source.name.endswith('.console.log'):
                continue
            log = source.read_text(errors='replace')
            assert 'PASS ' in log and 'Errors: 0,' in log
            assert not re.search(r'\*\* (Fatal|Error):', log)
            copy(source, 'validation/'+run+'/'+source.name)
            tests.append(run+'/'+source.name)
        for name in ('compile.log', 'vendor.log', 'pll.log', 'encrypted.log'):
            if (folder/name).exists():
                copy(folder/name, 'validation/'+run+'/'+name)
    assert len(tests) == 22, tests
    for source in ASSETS.rglob('*'):
        if source.is_file() and source.parent.name in ('card', 'preview'):
            copy(source, str(source.relative_to(ASSETS)))
    copy(ASSETS/'manifest.json', 'images.json')
    reproduced = ROOT/'diagnostics/output/bottom_wave_assets02'
    for source in (ASSETS/'card').glob('*.BMP'):
        assert source.read_bytes() == (reproduced/'card'/source.name).read_bytes()
    manifest = {'baseline': '147ef7d / v0.19.0-s2-local.1 RTL',
                'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'build': build_name, 'timing_ns': metrics,
                'source_byte_comparisons': len(checked), 'production_files': production,
                'simulation_logs': tests, 'images_reproduced_byte_for_byte': 4,
                'board_status': 'pending', 'copied_files': []}
    for p in TARGET.rglob('*'):
        if p.is_file():
            manifest['copied_files'].append({'file': p.relative_to(TARGET).as_posix(), 'bytes': p.stat().st_size})
    (TARGET/'MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (TARGET/'.gitattributes').write_text('* -text\n', encoding='utf-8')
    print('PASS frozen candidate:', TARGET, metrics, len(tests), 'simulation logs')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', required=True)
    main(parser.parse_args().build)
