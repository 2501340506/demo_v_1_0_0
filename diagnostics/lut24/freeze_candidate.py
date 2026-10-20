"""Freeze a v0.24 LUT-reduction local candidate; never overwrites a release.

Checks the build gates (strict positive setup/hold, zero TNS, no ERROR,
bitstream, audits, sources byte-identical to the committed tree), then copies
the bit, reports, audit, validation logs and the production files changed
since the plan baseline.
"""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'diagnostics/output'
BASELINE_TAG = 'v0.24.0-plan.1'
BASELINE_RESOURCES = dict(lut=18183, reg=12119, bram=53, bram32k=2, dsp=13)
# Validation runs (diagnostics/output/<run>) copied as *.log / *.txt evidence.
VALIDATION = (
    'lut24_s1_scanner1', 'lut24_s1_panel_layer1', 'lut24_s2_scanner_try2', 'lut24_s2_backend1',
    'lut24_s2_reg1_directories', 'lut24_s2_reg1_lfn',
    'lut24_s3_reg1_header', 'lut24_s3_reg1_decoder', 'lut24_s3_reg1_stream',
    'lut24_s3_reg1_audio_control', 'lut24_s3_reg1_voice', 'lut24_s3_reg1_narration',
    'lut24_s3_reg1_reader_scale0', 'lut24_s3_reader_scale_compare2',
) + tuple(f'lut24_s3_reg3_ctrl{i}' for i in range(24)) + ('lut24_s3_reg3_fast_metrics',)
CONSOLES = ('lut24_s1_units1.console.log', 'lut24_s3_reg3.console.log', 'lut24_s3_scale_compare2.console.log')


def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True, encoding='utf-8')


def freeze(name, stage, number):
    build = OUTPUT / name
    phy = build / 'TD_project/demo_Runs/phy_1'
    target = ROOT / f'releases/v0.24.0/{stage}-local.{number}'
    assert not target.exists(), 'Choose a new candidate; never overwrite a release'
    metrics = {k: float(re.search(k + r':\s*([-\d.]+)ns', read(phy / 'final_timing.rpt'))[1])
               for k in ('SWNS', 'HWNS', 'STNS', 'HTNS')}
    assert metrics['SWNS'] > 0 and metrics['HWNS'] > 0 and metrics['STNS'] == metrics['HTNS'] == 0, metrics
    area = read(phy / 'demo_phy.area')
    resources = {k: int(re.search(r'^#' + k + r'\s+(\d+)', area, re.M)[1]) for k in BASELINE_RESOURCES}
    assert resources['lut'] < BASELINE_RESOURCES['lut'], resources
    review = json.loads((build / 'timing_audit/warning_review.json').read_text(encoding='utf-8'))
    assert review['reviewed'] and review['font_rom_initialization_verified'] and review['constraints_byte_identical']
    assert review.get('review_notes'), 'warning review notes missing'
    for stage_dir in ('syn_1', 'phy_1'):
        log = read(build / f'TD_project/demo_Runs/{stage_dir}/build_{name}.log')
        assert not re.search(r'\bERROR:', log)
        if stage_dir == 'phy_1':
            assert 'Generate bitstream completely' in log
    checked = []
    for source in sorted((build / 'user_source').rglob('*')):
        if source.is_file():
            relative = source.relative_to(build)
            assert source.read_bytes() == (ROOT / relative).read_bytes(), str(relative)
            checked.append(relative.as_posix())
    assert len(checked) == len(git('ls-files', 'user_source').splitlines())
    assert not git('status', '--porcelain', '--', 'user_source')
    production = [p for p in git('diff', '--name-only', BASELINE_TAG, 'HEAD', '--', 'user_source').splitlines() if p]
    tools = [p for p in git('diff', '--name-only', BASELINE_TAG, 'HEAD', '--', 'diagnostics').splitlines() if p]

    def copy(source, relative):
        dest = target / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        assert dest.read_bytes() == source.read_bytes(), relative

    copy(phy / 'demo.bit', 'demo.bit')
    for path in production + tools:
        copy(ROOT / path, 'sources/' + path)
    copy(build / 'TD_project/demo.al', 'reproduce/demo.al')
    for path in ('diagnostics/bottom_waveform/run_td.ps1', 'diagnostics/run_td_build.ps1',
                 'diagnostics/disaster_selector/audit_s2.ps1', 'diagnostics/publicity_mode/run_m4_audit.ps1',
                 'diagnostics/narration_subtitles/check_font_map.py', 'diagnostics/lut24/review_build.py'):
        copy(ROOT / path, 'reproduce/' + path)
    for path in ('final_timing.rpt', 'demo_phy.area', 'settings.cfg', f'build_{name}.log'):
        copy(phy / path, 'reports/' + path)
    for path in ('demo_gate.area', 'settings.cfg', f'build_{name}.log'):
        copy(build / 'TD_project/demo_Runs/syn_1' / path, 'reports/synthesis/' + path)
    for path in ('audit.timing', 'check_timing.txt', 'exceptions.timing', 'sw3_sync.timing',
                 'console.log', 'exceptions.log', 'audit.tcl', 'exceptions.tcl',
                 'warning_review.json', 'font_rom_check.json'):
        copy(build / 'timing_audit' / path, 'reports/audit/' + path)
    copy(build / 'user_source/constraints_source/timing.sdc', 'reports/timing.sdc')
    (target / 'reports/source_check.json').write_text(
        json.dumps(dict(method='full byte comparison with committed tree', files=checked), indent=2) + '\n', encoding='utf-8')
    copied = 0
    for run in VALIDATION:
        directory = OUTPUT / run
        assert directory.is_dir(), run
        for log in sorted(directory.rglob('*')):
            parts = log.relative_to(directory).parts
            if log.is_file() and log.suffix in ('.log', '.txt') and not any(p == 'work' or p.endswith('_work') for p in parts):
                copy(log, f'validation/{run}/' + '/'.join(parts))
                copied += 1
    for console in CONSOLES:
        copy(OUTPUT / console, 'validation/' + console)
    manifest = dict(baseline=BASELINE_TAG, source_commit=git('rev-parse', 'HEAD').strip(), build=name,
                    metrics_ns=metrics, resources=resources, baseline_resources=BASELINE_RESOURCES,
                    bit_bytes=(target / 'demo.bit').stat().st_size, production_files=production,
                    validation_runs=list(VALIDATION), validation_files=copied)
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('Frozen', target, json.dumps(dict(metrics=metrics, resources=resources, files=copied)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', required=True)
    parser.add_argument('--stage', required=True)
    parser.add_argument('--number', type=int, default=1)
    a = parser.parse_args()
    freeze(a.build, a.stage, a.number)
