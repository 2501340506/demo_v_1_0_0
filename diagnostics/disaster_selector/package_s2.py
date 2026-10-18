"""Freeze an S2 candidate only after logs, exact inputs and routed timing pass."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'diagnostics/output'
spec = importlib.util.spec_from_file_location('s1', Path(__file__).with_name('package_s1.py'))
s1 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s1)
checks = s1.checks
S1 = dict(lut=15780, reg=10878, bram9k=52, bram32k=2, dsp=26)


def review(build):
    result = {'audit_summary': checks.audit_summary(build/'timing_audit/check_timing.txt'),
              'warning_delta_from_s1': {}}
    for run in ('syn_1', 'phy_1'):
        def warnings(path):
            return {re.sub(r'\(\d+\)', '(line)', re.sub(r'disaster_s[12]_td_attempt\d+', 'BUILD', line)).strip()
                    for line in checks.read_log(path).splitlines()
                    if re.search(r'WARNING|Warning|WARN-', line)}
        now = warnings(build/f'TD_project/demo_Runs/{run}/build_{build.name}.log')
        old = warnings(ROOT/f'releases/v0.19.0/s1-local.1/reports/{run}_build.log')
        result['warning_delta_from_s1'][run] = {'new': sorted(now-old), 'gone': sorted(old-now)}
    return result


def package(build, candidate, log_config):
    release = ROOT/'releases/v0.19.0'/candidate
    assert re.fullmatch(r's2-local\.[1-9]\d*', candidate), candidate
    assert not release.exists(), 'Never overwrite a candidate'
    phy = build/'TD_project/demo_Runs/phy_1'
    timing = checks.read_log(phy/'final_timing.rpt')
    margins = {n: float(re.search(n+r':\s*([-\d.]+)ns', timing)[1]) for n in ('SWNS','HWNS','STNS','HTNS')}
    assert margins['SWNS'] > 0 and margins['HWNS'] > 0, margins
    assert margins['STNS'] == margins['HTNS'] == 0, margins
    area = checks.read_log(phy/'demo_phy.area')
    resources = {n: int(re.search(r'(?m)^\s*#'+n+r'\s+(\d+)', area)[1]) for n in s1.LIMITS}
    assert all(resources[n] <= s1.LIMITS[n] for n in resources), resources
    assert not re.search(r'u_uart_logger|u_uart_rx|u_subtitle_control|u_subtitle_commit', area)
    for run in ('syn_1','phy_1'):
        log = checks.read_log(build/f'TD_project/demo_Runs/{run}/build_{build.name}.log')
        assert not re.search(r'\bERROR[: ]|\bTMR-250[79]\b', log, re.I), run
        if run == 'phy_1':
            assert 'Generate bitstream completely' in log
    inputs = [Path('TD_project/demo.al')]
    inputs += [(ROOT/'TD_project'/p).resolve().relative_to(ROOT) for p in re.findall(
        r'<File Path="([^"]+)"', (ROOT/inputs[0]).read_text(encoding='utf-8'))]
    for name in inputs + [Path('diagnostics/run_td_build.ps1')]:
        assert (ROOT/name).read_bytes() == (build/name).read_bytes(), name
    audit = checks.read_log(build/'timing_audit/check_timing.txt')
    for marker in ('checking no clock(0)','checking invalid constraint(0)','checking combinational loops(0)'):
        assert marker in audit, marker
    exceptions = checks.read_log(build/'timing_audit/exceptions.log')
    for marker in ('SW3_PORT_COUNT=1', 'SW3_INPUT_REGISTER_COUNT=1', 'UART_LOG_COUNT=0'):
        assert marker in exceptions, marker
    sw3_sync = checks.read_log(build/'timing_audit/sw3_sync.timing')
    assert 'sw3_syn_4' in sw3_sync and 'switch_filter/sync1' in sw3_sync, 'SW3 downstream synchronizer must remain timed'
    assert review(build) == json.loads((build/'audit_review.json').read_text(encoding='utf-8'))
    assert (build/'AUDIT_REVIEW.md').is_file(), 'Record actual exception/warning review'
    logs = json.loads(log_config.read_text(encoding='utf-8'))
    assert len(logs) >= 70, 'Incomplete regression evidence selection'
    for name, marker in logs.items():
        assert not Path(name).is_absolute() and '..' not in Path(name).parts
        checks.check_log(OUTPUT/name, marker)
    compile_logs = []
    for folder in sorted({Path(n).parent for n in logs}):
        for path in sorted((OUTPUT/folder).glob('*.log')):
            if 'compile' in path.name or path.name in ('vendor.log','pll.log','encrypted.log'):
                checks.check_log(path)
                compile_logs.append(path.relative_to(OUTPUT).as_posix())
    changed = subprocess.check_output(['git','-c','core.quotepath=false','diff','afffa80','--name-only','--','user_source','TD_project'], cwd=ROOT).decode('utf-8').splitlines()
    changed += subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','user_source','TD_project'], cwd=ROOT).decode('utf-8').splitlines()
    changed = sorted(set(changed))
    assert len(changed) >= 20 and (phy/'demo.bit').stat().st_size > 0
    release.mkdir(parents=True)
    (release/'.gitattributes').write_text('** -text -whitespace\n', encoding='utf-8')

    def copy(src, dest):
        target = release/dest
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
        assert src.read_bytes() == target.read_bytes(), target

    copy(phy/'demo.bit', 'demo.bit')
    for name in ('final_timing.rpt','demo_phy.area'):
        copy(phy/name, Path('reports')/name)
    for run in ('syn_1','phy_1'):
        copy(build/f'TD_project/demo_Runs/{run}/build_{build.name}.log', Path('reports')/f'{run}_build.log')
        copy(build/f'TD_project/demo_Runs/{run}/settings.cfg', Path('reports')/f'{run}_settings.cfg')
    for name in ('check_timing.txt','audit.timing','exceptions.timing','exceptions.log','sw3_sync.timing'):
        copy(build/'timing_audit'/name, Path('reports')/name)
    for name in ('audit_review.json','AUDIT_REVIEW.md'):
        copy(build/name, Path('reports')/name)
    for name in list(logs) + compile_logs:
        copy(OUTPUT/name, Path('validation')/name)
    copy(log_config, 'validation/logs.json')
    for name in changed:
        copy(ROOT/name, Path('sources')/name)
    for name in ('diagnostics/run_td_build.ps1','diagnostics/mountain_scene/build_m5.ps1'):
        copy(ROOT/name, Path('reproduce')/name)
    for name in ('menu_actual.png','menu_expected_0.png','menu_expected_4.png'):
        copy(OUTPUT/'disaster_s2_pixels05'/name, Path('previews')/name)
    result = {'baseline':'7e3ac02','stage_input':'afffa80','build':build.name,
              'resources':resources,'delta_from_baseline':{n:resources[n]-s1.BASELINE[n] for n in resources},
              'delta_from_s1':{n:resources[n]-S1[n] for n in resources},'timing_ns':margins,
              'input_count':len(inputs),'simulations':logs,'compile_logs':compile_logs,
              'modified_sources':changed,'bit_bytes':(phy/'demo.bit').stat().st_size,'board':'pending'}
    (release/'validation/results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (release/'MANIFEST.md').write_text('# S2 build inputs\n\nBaseline 7e3ac02; stage input afffa80. All listed inputs and the root TD runner match the isolated build byte for byte. Source backup includes only production changes since S1.\n\n'+
        '\n'.join(f'- {p.as_posix()} ({(ROOT/p).stat().st_size} bytes)' for p in inputs)+'\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('review','package'))
    parser.add_argument('build')
    parser.add_argument('--candidate', default='s2-local.1')
    parser.add_argument('--logs', type=Path, default=Path(__file__).with_name('s2_logs.json'))
    args = parser.parse_args()
    build = OUTPUT/args.build
    if args.action == 'review':
        target = build/'audit_review.json'
        assert not target.exists(), 'Review already recorded'
        target.write_text(json.dumps(review(build), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(target.read_text(encoding='utf-8'))
    else:
        package(build, args.candidate, args.logs)
