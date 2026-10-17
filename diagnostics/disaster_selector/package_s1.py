"""Freeze S1 only after current inputs, simulations and routed timing pass."""
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('checks', ROOT/'diagnostics/mountain_scene/package_m6.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
BASELINE = dict(lut=14092, reg=9530, bram9k=46, bram32k=2, dsp=13)
LIMITS = dict(lut=19600, reg=19600, bram9k=64, bram32k=16, dsp=29)


def simulation_logs():
    logs = {}
    for folder, names in {
        'disaster_s1_layers02': ['tb_disaster_layer', 'tb_m3v3_sweep', 'tb_m3v3_card'],
        'disaster_s1_metadata01': ['case0', 'case5', 'case7', 'case8', 'case9', 'identity_blank'],
        'disaster_s1_status02': ['tb_m5_status'],
        'disaster_s1_pixels02': ['tb_m5_pixels'],
        'disaster_s1_voice01': ['tb_m4_top'],
        'disaster_s1_legacy02': ['tb_scenario_top', 'tb_m6_top'],
        'disaster_s1_controls01': ['tb_m5_parameters', 'tb_m5_scenario', 'tb_m5_preview', 'tb_m5_recovery',
                                  'tb_volume', 'tb_adjust_cdc', 'tb_adjust_keys', 'tb_adjust_osd', 'tb_adjust_decimal'],
    }.items():
        logs.update({f'{folder}/{name}.log': 'PASS ' for name in names})
    unit = ROOT/'diagnostics/output/disaster_s1_unit02'
    for path in unit.glob('tb_*.log'):
        if not path.name.endswith('.console.log'):
            logs[path.relative_to(ROOT/'diagnostics/output').as_posix()] = 'PASS '
    assert len(logs) >= 37, len(logs)
    return logs


def warning_set(path):
    return sorted({re.sub(r'\(\d+\)', '(line)',
                         re.sub(r'(disaster_s1_td_attempt\d+|uart_reduction_td_attempt\d+)', 'BUILD', line)).strip()
                   for line in checks.read_log(path).splitlines()
                   if re.search(r'WARNING|Warning|WARN-', line)})


def review(build):
    prior = ROOT/'releases/v0.18.0/uart-s1-local.1/reports'
    result = {'audit_summary': checks.audit_summary(build/'timing_audit/check_timing.txt'), 'warning_delta': {}}
    for run in ('syn_1', 'phy_1'):
        now = set(warning_set(build/f'TD_project/demo_Runs/{run}/build_{build.name}.log'))
        old = set(warning_set(prior/f'{run}_build.log'))
        result['warning_delta'][run] = {'new': sorted(now-old), 'gone': sorted(old-now)}
    return result


def package(build_name, candidate):
    output = ROOT/'diagnostics/output'
    build = output/build_name
    phy = build/'TD_project/demo_Runs/phy_1'
    release = ROOT/'releases/v0.19.0'/candidate
    assert not release.exists(), 'Never overwrite a candidate'
    timing = checks.read_log(phy/'final_timing.rpt')
    margins = {n: float(re.search(n+r':\s*([-\d.]+)ns', timing)[1]) for n in ('SWNS', 'HWNS', 'STNS', 'HTNS')}
    assert margins['SWNS'] > 0 and margins['HWNS'] > 0, margins
    assert margins['STNS'] == margins['HTNS'] == 0, margins
    area = checks.read_log(phy/'demo_phy.area')
    resources = {n: int(re.search(r'(?m)^\s*#'+n+r'\s+(\d+)', area)[1]) for n in LIMITS}
    assert all(resources[n] <= LIMITS[n] for n in LIMITS), resources
    assert not re.search(r'u_uart_logger|u_uart_rx|u_subtitle_control|u_subtitle_commit', area)
    assert (phy/'demo.bit').stat().st_size > 0
    for run in ('syn_1', 'phy_1'):
        log = checks.read_log(build/f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        assert not re.search(r'\bERROR[: ]|\bTMR-250[79]\b', log, re.I), run
        if run == 'phy_1':
            assert 'Generate bitstream completely' in log
    inputs = [Path('TD_project/demo.al')]
    inputs += [(ROOT/'TD_project'/p).resolve().relative_to(ROOT) for p in re.findall(
        r'<File Path="([^"]+)"', (ROOT/inputs[0]).read_text(encoding='utf-8'))]
    for p in inputs + [Path('diagnostics/run_td_build.ps1')]:
        assert (ROOT/p).read_bytes() == (build/p).read_bytes(), p
    audit = checks.read_log(build/'timing_audit/check_timing.txt')
    for marker in ('checking no clock(0)', 'checking invalid constraint(0)', 'checking combinational loops(0)'):
        assert marker in audit, marker
    review_file = build/'audit_review.json'
    assert review(build) == json.loads(review_file.read_text(encoding='utf-8')), 'Audit must be reviewed first'
    logs = simulation_logs()
    for name, marker in logs.items():
        checks.check_log(output/name, marker)
    compile_logs = []
    for folder in sorted({Path(n).parent for n in logs}):
        for p in sorted((output/folder).glob('*.log')):
            if 'compile' in p.name or p.name in ('vendor.log', 'pll.log', 'encrypted.log'):
                checks.check_log(p)
                compile_logs.append(p.relative_to(output))
    changed = subprocess.check_output(['git', 'diff', '7e3ac02', '--name-only', '--', 'user_source', 'TD_project'], cwd=ROOT).decode().splitlines()
    added = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', 'user_source', 'TD_project'], cwd=ROOT).decode().splitlines()
    changed = sorted(set(changed + added))
    release.mkdir(parents=True)
    (release/'.gitattributes').write_text('** -text -whitespace\n', encoding='utf-8')

    def copy(src, dest):
        target = release/dest
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
        assert src.read_bytes() == target.read_bytes(), target

    copy(phy/'demo.bit', 'demo.bit')
    for n in ('final_timing.rpt', 'demo_phy.area'):
        copy(phy/n, Path('reports')/n)
    for run in ('syn_1', 'phy_1'):
        folder = build/f'TD_project/demo_Runs/{run}'
        copy(folder/f'build_{build_name}.log', Path('reports')/f'{run}_build.log')
        copy(folder/'settings.cfg', Path('reports')/f'{run}_settings.cfg')
    for n in ('check_timing.txt', 'audit.timing', 'exceptions.timing', 'exceptions.log'):
        copy(build/'timing_audit'/n, Path('reports')/n)
    copy(review_file, 'reports/audit_review.json')
    for name in list(logs) + compile_logs:
        copy(output/name, Path('validation')/name)
    for name in changed:
        copy(ROOT/name, Path('sources')/name)
    result = {'baseline': '7e3ac02', 'build': build_name, 'resources': resources,
              'delta': {n: resources[n]-BASELINE[n] for n in resources}, 'timing_ns': margins,
              'input_count': len(inputs), 'simulations': logs, 'modified_sources': changed,
              'compile_logs': [p.as_posix() for p in compile_logs], 'bit_bytes': (phy/'demo.bit').stat().st_size,
              'board': 'pending', 's2': 'not implemented'}
    (release/'validation/results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (release/'MANIFEST.md').write_text('# S1 build inputs\n\nBaseline 7e3ac02. All listed current inputs and build script match the isolated build byte for byte. Only changed production inputs are backed up.\n\n'+
        '\n'.join(f'- {p.as_posix()} ({(ROOT/p).stat().st_size} bytes)' for p in inputs)+'\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    if sys.argv[1] == 'review':
        build = ROOT/'diagnostics/output'/sys.argv[2]
        target = build/'audit_review.json'
        assert not target.exists()
        target.write_text(json.dumps(review(build), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(target.read_text(encoding='utf-8'))
    else:
        package(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 's1-local.1')
