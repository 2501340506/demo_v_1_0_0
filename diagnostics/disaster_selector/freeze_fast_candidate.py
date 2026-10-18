"""Freeze a timing-clean fast-start candidate with byte comparisons, no card writes."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'releases/v0.23.0/s2-local.1'
BASELINE = '31de2b0'
RUNS = ('fast_app_equivalence02', 'fast_backend03', 'fast_layer_equivalence02', 'fast_display06',
        'fast_controller19', 'fast_controller20', 'fast_writer01', 'fast_ui01', 'fast_directories03',
        'fast_cache_equivalence02', 'fast_m4_01', 'fast_pixels01', 'fast_unit04', 'fast_narration01', 'fast_preview05', 'fast_scaler02', 'fast_header09')


def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def copy(source, relative):
    target = TARGET / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    assert target.read_bytes() == source.read_bytes(), relative


def freeze(name):
    build = ROOT / 'diagnostics/output' / name
    phy = build / 'TD_project/demo_Runs/phy_1'
    metrics = {k: float(re.search(k+r':\s*([-\d.]+)ns', read(phy/'final_timing.rpt'))[1])
               for k in ('SWNS', 'HWNS', 'STNS', 'HTNS')}
    assert metrics['SWNS'] > 0 and metrics['HWNS'] > 0 and metrics['STNS'] == metrics['HTNS'] == 0
    assert not TARGET.exists(), 'Use a new candidate number'
    review = json.loads((build/'timing_audit/warning_review.json').read_text(encoding='utf-8'))
    assert review['reviewed'] and review['font_rom_initialization_verified'] and review['constraints_byte_identical']
    for stage in ('syn_1', 'phy_1'):
        log = read(build / f'TD_project/demo_Runs/{stage}/build_{name}.log')
        assert not re.search(r'\bERROR:', log)
        if stage == 'phy_1':
            assert 'Generate bitstream completely' in log
    checked = []
    for source in sorted((build/'user_source').rglob('*')):
        if source.is_file():
            relative = source.relative_to(build)
            assert source.read_bytes() == (ROOT/relative).read_bytes(), str(relative)
            checked.append(relative.as_posix())
    assert len(checked) == 134, len(checked)
    changed = subprocess.check_output(['git', 'diff', '--name-only', BASELINE, 'HEAD'], cwd=ROOT, text=True, encoding='utf-8').splitlines()
    production = [p for p in changed if p.startswith('user_source/')]
    assert len(production) == 13, production
    assert not subprocess.check_output(['git', 'diff', 'HEAD', '--', 'user_source'], cwd=ROOT), 'Commit source before freezing'
    area = read(phy/'demo_phy.area')
    resources = {k: int(re.search(r'^#'+k+r'\s+(\d+)', area, re.M)[1]) for k in ('lut', 'reg', 'bram', 'bram32k', 'dsp')}
    assert resources['lut'] <= 19600 and resources['reg'] <= 19600 and resources['bram'] <= 64 and resources['bram32k'] <= 16 and resources['dsp'] <= 29
    tests = []
    for run in RUNS:
        for source in sorted((ROOT/'diagnostics/output'/run).rglob('*.log')):
            if source.name.endswith('.console.log') or source.name == 'console.log':
                continue
            log = read(source)
            if 'PASS ' in log and 'Errors: 0,' in log:
                assert not re.search(r'\*\* (Fatal|Error):', log)
                tests.append(source.relative_to(ROOT/'diagnostics/output').as_posix())
    assert len(tests) == 81, tests
    copy(phy/'demo.bit', 'demo.bit')
    for path in production:
        copy(ROOT/path, 'sources/'+path)
    helpers = [p for p in changed if p.startswith(('tools/', 'diagnostics/disaster_selector/', 'diagnostics/publicity_mode/'))
               or p in ('diagnostics/image_scaling/tb_preview_control.sv',
                        'diagnostics/image_scaling/tb_scale_stream.sv',
                        'diagnostics/media_adjust/run_header_lookahead.ps1')]
    for path in helpers:
        copy(ROOT/path, 'sources/'+path)
    copy(build/'TD_project/demo.al', 'reproduce/demo.al')
    for path in ('diagnostics/bottom_waveform/run_td.ps1', 'diagnostics/run_td_build.ps1',
                 'diagnostics/disaster_selector/audit_s2.ps1', 'diagnostics/publicity_mode/run_m4_audit.ps1',
                 'diagnostics/narration_subtitles/check_font_map.py',
                 'diagnostics/media_adjust/run_scaler.ps1', 'diagnostics/image_scaling/tb_scaler.sv',
                 'diagnostics/stability/tb_bmp24_decoder.sv'):
        copy(ROOT/path, 'reproduce/'+path)
    for path in ('final_timing.rpt', 'demo_phy.area', 'settings.cfg', f'build_{name}.log'):
        copy(phy/path, 'reports/'+path)
    for path in ('demo_gate.area', 'settings.cfg', f'build_{name}.log'):
        copy(build/'TD_project/demo_Runs/syn_1'/path, 'reports/synthesis/'+path)
    for path in ('audit.timing', 'check_timing.txt', 'exceptions.timing', 'sw3_sync.timing', 'console.log',
                 'exceptions.log', 'audit.tcl', 'exceptions.tcl', 'warning_review.json', 'font_rom_check.json'):
        copy(build/'timing_audit'/path, 'reports/audit/'+path)
    copy(build/'user_source/constraints_source/timing.sdc', 'reports/timing.sdc')
    (TARGET/'reports/source_check.json').write_text(json.dumps(dict(method='full byte comparison', files=checked), indent=2)+'\n', encoding='utf-8')
    for path in tests:
        copy(ROOT/'diagnostics/output'/path, 'validation/'+path)
    for run in RUNS:
        for path in ('compile.log', 'vendor.log', 'pll.log', 'encrypted.log'):
            source = ROOT/'diagnostics/output'/run/path
            if source.exists():
                copy(source, 'validation/'+run+'/'+path)
    copy(ROOT/'diagnostics/output/fast_preview05/mux_proof.txt', 'validation/fast_preview05/mux_proof.txt')
    for run in ('fast_metrics_baseline03', 'fast_metrics_current04'):
        for case in (0, 11, 16):
            copy(ROOT/f'diagnostics/output/{run}/metrics{case}.txt', f'validation/{run}/metrics{case}.txt')
    assets = ROOT/'diagnostics/output/fast_resource_pack01'
    pack_tests = read(assets/'scene_pack_tests.log')
    assert 'Ran 8 tests' in pack_tests and re.search(r'^OK\s*$', pack_tests, re.M)
    copy(assets/'scene_pack_tests.log', 'validation/scene_pack_tests.log')
    for path in ('full_sd_resources.zip', 'thumbnail_additions.zip', 'assets_manifest.json'):
        copy(assets/path, 'assets/'+path)
    for source in sorted((assets/'card').rglob('THUMB.BMP')):
        copy(source, 'assets/'+source.relative_to(assets).as_posix())
    for path in ('docs/四宫格与开机加速计时及资源说明.md', 'docs/四宫格与开机加速实板计时模板.csv'):
        copy(ROOT/path, 'board/'+Path(path).name)
    (TARGET/'.gitattributes').write_text('* -text\n', encoding='utf-8')
    manifest = dict(baseline=BASELINE+' / v0.22.0-s1-local.1',
                    source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    build=name, timing_ns=metrics, resources=resources, source_byte_comparisons=len(checked),
                    production_files=production, simulation_logs=tests, board_status='pending',
                    card_status='read-only source; generated packages not installed', files=[])
    manifest['files'] = [dict(file=p.relative_to(TARGET).as_posix(), bytes=p.stat().st_size)
                         for p in sorted(TARGET.rglob('*')) if p.is_file()]
    (TARGET/'MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('PASS frozen', TARGET, metrics, resources, len(tests), 'simulation logs')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', required=True)
    freeze(p.parse_args().build)
