"""Freeze the UART reduction candidate after measured timing and log checks."""
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('checks', ROOT / 'diagnostics/mountain_scene/package_m6.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def warning_set(path):
    result = set()
    for line in checks.read_log(path).splitlines():
        if re.search(r'WARNING|Warning|WARN-', line):
            line = re.sub(r'(publicity_m5_td_attempt27|uart_reduction_td_attempt\d+)', 'BUILD', line)
            result.add(re.sub(r'\(\d+\)', '(line)', line).strip())
    return result


def review(build_name):
    build = ROOT / 'diagnostics/output' / build_name
    prior = ROOT / 'releases/v0.18.0/m5-local.1/reports'
    delta = {}
    for run in ('syn_1', 'phy_1'):
        now = warning_set(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        old = warning_set(prior / f'{run}_build.log')
        delta[run] = {'new': sorted(now - old), 'gone': sorted(old - now)}
    return {'audit_summary': checks.audit_summary(build / 'timing_audit/check_timing.txt'),
            'warning_delta': delta}


def package(build_name):
    output = ROOT / 'diagnostics/output'
    build = output / build_name
    phy = build / 'TD_project/demo_Runs/phy_1'
    release = ROOT / 'releases/v0.18.0/uart-s1-local.1'
    assert not release.exists(), 'Never overwrite a candidate'
    timing = checks.read_log(phy / 'final_timing.rpt')
    margins = {name: float(re.search(name + r':\s*([-\d.]+)ns', timing)[1])
               for name in ('SWNS', 'HWNS', 'STNS', 'HTNS')}
    assert margins['SWNS'] > 0 and margins['HWNS'] > 0, margins
    assert margins['STNS'] == margins['HTNS'] == 0, margins
    area = checks.read_log(phy / 'demo_phy.area')
    resources = {name: int(re.search(r'(?m)^\s*#' + name + r'\s+(\d+)', area)[1])
                 for name in ('lut', 'reg', 'bram9k', 'bram32k', 'dsp')}
    assert resources['lut'] < 16022 and resources['bram9k'] == 46, resources
    assert resources['bram32k'] == 2 and resources['dsp'] == 13, resources
    assert not re.search(r'u_uart_logger|u_uart_rx|u_subtitle_control|u_subtitle_commit', area), area
    assert (phy / 'demo.bit').stat().st_size > 0
    for run in ('syn_1', 'phy_1'):
        text = checks.read_log(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        assert not re.search(r'\bERROR[: ]|\bTMR-250[79]\b', text, re.I), run
        if run == 'phy_1':
            assert 'Generate bitstream completely' in text
    inputs = [Path('TD_project/demo.al')]
    inputs += [(ROOT / 'TD_project' / p).resolve().relative_to(ROOT)
               for p in re.findall(r'<File Path="([^"]+)"', (ROOT / inputs[0]).read_text(encoding='utf-8'))]
    for name in inputs + [Path('diagnostics/run_td_build.ps1')]:
        assert (ROOT / name).read_bytes() == (build / name).read_bytes(), name
    probe = output / 'uart_reduction_constraints04'
    assert (ROOT / 'user_source/constraints_source/timing.sdc').read_bytes() == (probe / 'disabled.sdc').read_bytes()
    subprocess.run([sys.executable, '-I', '-X', 'utf8', str(ROOT / 'diagnostics/uart_reduction/verify_constraints.py'), str(probe)], check=True)
    assert (ROOT / '问题小记录.txt').read_bytes() == (output / 'uart_reduction_baseline01/personal_record.bin').read_bytes()
    changed = subprocess.check_output(['git', 'diff', '075ab05', '--name-only', '--', 'user_source', 'TD_project'], cwd=ROOT).decode().splitlines()
    assert changed == ['user_source/constraints_source/timing.sdc', 'user_source/hdl_source/top_tf_hdmi_audio.v'], changed
    exceptions = checks.read_log(build / 'timing_audit/exceptions.timing')
    assert 'get_ports uart_tx' not in exceptions, 'Constant TX constraint broadened to internal paths'
    audit = checks.read_log(build / 'timing_audit/check_timing.txt')
    for marker in ('checking no clock(0)', 'checking invalid constraint(0)', 'checking combinational loops(0)'):
        assert marker in audit, marker
    review_file = build / 'audit_review.json'
    assert review(build_name) == json.loads(review_file.read_text(encoding='utf-8')), 'Audit differs from reviewed file'
    logs = {
        **{f'uart_reduction_options01/{name}.log': 'PASS UART options' for name in ('options00', 'options01', 'options10', 'options11')},
        'uart_reduction_options01/subtitle.log': 'PASS UART subtitle:',
        'uart_reduction_options01/logger.log': 'PASS ',
        'uart_reduction_pixels01/tb_m5_pixels.log': 'PASS M5 production final pixels:',
        'uart_reduction_status01/tb_m5_status.log': 'PASS ',
        'uart_reduction_legacy01/tb_scenario_top.log': 'PASS ',
        'uart_reduction_legacy01/tb_m6_top.log': 'PASS ',
        'uart_reduction_voice01/tb_m4_top.log': 'PASS ',
    }
    for name, marker in logs.items():
        checks.check_log(output / name, marker)
    compile_logs = []
    for folder in sorted({Path(name).parent for name in logs}):
        for path in sorted((output / folder).glob('*.log')):
            if path.name in ('compile.log', 'vendor.log', 'pll.log', 'encrypted.log'):
                checks.check_log(path)
                compile_logs.append(path.relative_to(output))
    release.mkdir(parents=True)
    (release / '.gitattributes').write_text('** -text -whitespace\n', encoding='utf-8')

    def copy(src, dest):
        target = release / dest
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
        assert src.read_bytes() == target.read_bytes(), target

    copy(phy / 'demo.bit', 'demo.bit')
    for name in ('final_timing.rpt', 'demo_phy.area'):
        copy(phy / name, Path('reports') / name)
    for run in ('syn_1', 'phy_1'):
        folder = build / f'TD_project/demo_Runs/{run}'
        copy(folder / f'build_{build_name}.log', Path('reports') / f'{run}_build.log')
        copy(folder / 'settings.cfg', Path('reports') / f'{run}_settings.cfg')
    for name in ('check_timing.txt', 'audit.timing', 'exceptions.timing', 'exceptions.log'):
        copy(build / 'timing_audit' / name, Path('reports') / name)
    copy(review_file, 'reports/audit_review.json')
    for name in list(logs) + compile_logs:
        copy(output / name, Path('validation') / name)
    for name in changed:
        copy(ROOT / name, Path('sources') / name)
    for name in ('enabled.log', 'disabled.log', 'enabled.exceptions', 'disabled.exceptions',
                 'enabled.timing', 'disabled.timing', 'enabled.sdc', 'disabled.sdc'):
        copy(probe / name, Path('validation/constraint_probe') / name)
    summary = {'baseline': '075ab05', 'build': build_name, 'resources': resources,
               'timing_ns': margins, 'input_count': len(inputs), 'simulations': logs,
               'compile_logs': [p.as_posix() for p in compile_logs], 'bit_bytes': (phy / 'demo.bit').stat().st_size}
    (release / 'validation/results.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lines = ['# UART S1 构建输入', '', f'基线075ab05，构建{build_name}。',
             f'{len(inputs)}个工程输入及根构建脚本与隔离快照逐字节一致；bit与构建原文件逐字节一致。',
             '仅top_tf_hdmi_audio.v及timing.sdc变化并备份；其余输入引用基线。个人记录与开始副本逐字节一致，不纳入提交。',
             '', f'资源：{resources}；时序(ns)：{margins}。', '', '## 输入清单', '']
    lines += [f'- {p.as_posix()} ({(ROOT / p).stat().st_size} bytes)' for p in inputs]
    (release / 'MANIFEST.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    if sys.argv[1] == 'review':
        result = review(sys.argv[2])
        target = ROOT / 'diagnostics/output' / sys.argv[2] / 'audit_review.json'
        assert not target.exists(), target
        target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(target.read_text(encoding='utf-8'))
    else:
        package(sys.argv[1])
