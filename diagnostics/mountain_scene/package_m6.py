"""Freeze an M6 candidate after simulation, TD and audit; compare bytes, no hashes."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def read_log(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8', errors='replace')


def known_warning(line):
    if re.search(r'(vopt-(2685|2718|2121)|vsim-(3017|3722)|vlog-2121)', line):
        return True
    if re.search(r'(vopt-2241|vsim-3015)', line):
        return 'sys_pll_s3.v(89)' in line and 'load_reg' in line
    if '(vlog-2275)' in line:
        return 'al_phy_glbl.v(23)' in line and "'glbl' already exists and will be overwritten." in line
    return line.strip() == '** Warning: (vlog-13288) Multiple macros defined in +define+ command line switch.'


def check_log(path, marker=None):
    text = read_log(path)
    assert 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error)', text), path
    if marker:
        assert marker in text, (path, marker)
    for line in text.splitlines():
        if '** Warning:' in line:
            assert known_warning(line), (path, line)


def audit_summary(path):
    return [line.strip() for line in read_log(path).splitlines()
            if re.search(r'There (are|is)|DummyNode|set_(multicycle_path|max_delay|input_delay)', line)]


def package(build_name, candidate):
    output = ROOT / 'diagnostics/output'
    build = output / build_name
    phy = build / 'TD_project/demo_Runs/phy_1'
    release = ROOT / 'releases/v0.17.0' / candidate
    assert not release.exists(), 'Never overwrite a candidate'
    timing = read_log(phy / 'final_timing.rpt')
    for field in ('SWNS', 'HWNS'):
        value = re.search(field + r':\s*([-\d.]+)ns', timing)
        assert value and float(value[1]) > 0, f'Nonpositive {field}'
    area = read_log(phy / 'demo_phy.area')
    lut = re.search(r'(?m)^#lut\s+(\d+)', area)
    assert lut and int(lut[1]) <= 16660, 'LUT above 85% target'
    assert re.search(r'(?m)^#bram32k\s+2\b', area), 'Expected two BRAM32k'
    # M6 uses two BRAM32k blocks; its uncompressed bit length differs from M4.
    assert (phy / 'demo.bit').stat().st_size == 673856
    for run in ('syn_1', 'phy_1'):
        text = read_log(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        assert not re.search(r'\bERROR:', text, re.I)
        if run == 'phy_1':
            assert 'Generate bitstream completely' in text
    inputs = [Path('TD_project/demo.al')]
    inputs += [(ROOT / 'TD_project' / n).resolve().relative_to(ROOT)
               for n in re.findall(r'<File Path="([^"]+)"', (ROOT / inputs[0]).read_text(encoding='utf-8'))]
    for name in inputs:
        assert (ROOT / name).read_bytes() == (build / name).read_bytes(), f'Build input mismatch: {name}'
    build_script = Path('diagnostics/run_td_build.ps1')
    assert (ROOT / build_script).read_bytes() == (build / build_script).read_bytes(), 'Build script mismatch'
    log_config = ROOT / 'diagnostics/mountain_scene/m6_logs.json'
    logs = json.loads(log_config.read_text(encoding='utf-8'))
    assert logs, 'No validation logs selected'
    for name, marker in logs.items():
        check_log(output / name, marker)
    compile_logs = []
    for folder in sorted({Path(name).parent for name in logs}):
        for path in sorted((output / folder).glob('*.log')):
            if 'compile' in path.name or path.name in ('vendor.log', 'encrypted.log', 'pll.log'):
                check_log(path)
                compile_logs.append(path.relative_to(output))
    audit = build / 'timing_audit'
    baseline = ROOT / 'releases/v0.17.0/m1-local.1/reports/check_timing.txt'
    # New RAM primitives add one dummy-node model category to this TD audit.
    # Check its exact instances; do not suppress any other audit difference.
    audit_text = read_log(audit / 'check_timing.txt')
    bram_dummy = re.search(r'DummyNode in Model: EG_PHY_BRAM32K\s+(.*?)\s+DummyNode in Model:',
                           audit_text, re.S)
    assert bram_dummy and set(bram_dummy[1].split()) == {
        'g_scene_text$font_ram/ram.dob[9]', 'g_scene_text$text_ram/ram.dob[9]'
    }, 'Unexpected BRAM dummy pins'
    expected_audit = audit_summary(baseline)
    pos = expected_audit.index('There are 3 nodes are dangling. (HIGH)')
    expected_audit[pos:pos + 1] = ['There are 4 nodes are dangling. (HIGH)',
                                  'DummyNode in Model: EG_PHY_BRAM32K']
    assert audit_summary(audit / 'check_timing.txt') == expected_audit, 'Unexpected audit difference'
    def warning_set(path):
        # Compare diagnostic contents, not build-folder names or source line shifts.
        result = set()
        for line in read_log(path).splitlines():
            if re.search(r'WARNING|Warning|WARN-', line):
                line = re.sub(r'mountain(?:_scene)?_m[13456]_attempt\d+', 'BUILD', line)
                result.add(re.sub(r'\(\d+\)', '(line)', line))
        return result
    for run in ('syn_1', 'phy_1'):
        current = build / f'TD_project/demo_Runs/{run}/build_{build_name}.log'
        prior = ROOT / f'releases/v0.17.0/m1-local.1/reports/{run}_build.log'
        # These two diagnostics describe unsupported optional place hold knobs
        # on EG4. Final measured positive hold is still mandatory above.
        optional_place_warnings = {
            'OPT-5011 WARNING: Hide fixed number of slots for old device.',
            'OPT-5502 WARNING: Pre-route hold fixing do not support current device.',
        }
        new = {line.strip() for line in warning_set(current) - warning_set(prior)}
        assert not new - optional_place_warnings, f'New TD diagnostic: {run}: {new}'
    changed = set(subprocess.check_output(['git', 'diff', 'v0.17.0-m5-local.1', '--name-only', '--',
                                          'user_source', 'TD_project'], cwd=ROOT).decode('utf-8').splitlines())
    changed.update(subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', 'user_source', 'TD_project'], cwd=ROOT).decode('utf-8').splitlines())
    saved = [p for p in inputs if p.as_posix() in changed]
    assert saved and Path('user_source/hdl_source/scene/scene_text_overlay.v') in saved, saved
    tool_logs = ['mountain_m6_audio_tool01.log','mountain_m6_image_tool01.log','mountain_m6_text_tool01.log','mountain_m6_cards_tool02.log']
    for name in tool_logs:
        source = output/name
        assert re.search(r'Ran \d+ tests',read_log(source)) and re.search(r'^OK\s*$',read_log(source),re.M), source
        assert 'FAILED' not in read_log(source), source
    release.mkdir(parents=True)
    # Keep original evidence/source bytes, including tool-generated whitespace.
    (release / '.gitattributes').write_text(
        'reports/** -text -whitespace\n'
        'validation/** -text -whitespace\n'
        'sources/** -text -whitespace\n', encoding='utf-8')

    def copy(src, name):
        dst = release / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        assert src.read_bytes() == dst.read_bytes(), name

    copy(phy / 'demo.bit', Path('demo.bit'))
    for name in ('final_timing.rpt', 'demo_phy.area'):
        copy(phy / name, Path('reports') / name)
    for run in ('syn_1', 'phy_1'):
        folder = build / 'TD_project/demo_Runs' / run
        copy(folder / f'build_{build_name}.log', Path('reports') / f'{run}_build.log')
        copy(folder / 'settings.cfg', Path('reports') / f'{run}_settings.cfg')
    for name in ('check_timing.txt', 'audit.timing'):
        copy(audit / name, Path('reports') / name)
    for name in list(logs) + compile_logs:
        copy(output / name, Path('validation') / name)
    copy(log_config, Path('validation/logs.json'))
    for name in saved:
        copy(ROOT / name, Path('sources') / name)
    for name in (build_script, Path('diagnostics/mountain_scene/build_m5.ps1')):
        copy(ROOT / name, Path('reproduce') / name)
    copy(ROOT / 'diagnostics/mountain_scene/BOARD_VALIDATION_M6.md', Path('BOARD_VALIDATION.md'))
    for folder, card in (('m6_demo', 'demo_village'), ('flood_village', 'flood_village')):
        assets = ROOT / 'tools/scenes' / folder / 'generated'
        for name in [f'PIC{i}.BMP' for i in range(1,5)] + [f'SND{i}.PCM' for i in range(1,5)] + ['FONT.BIN','TEXT.BIN','manifest.json']:
            copy(assets/name, Path('cards')/card/name)
        for path in assets.rglob('*.png'):
            copy(path, Path('previews')/card/path.relative_to(assets))
    for name in tool_logs:
        source = output/name
        copy(source,Path('validation')/name)
    manifest = ['# M6 build inputs', '', f'Build: {build_name}; {len(inputs)} inputs compared byte-for-byte.',
                f'Bit: {(phy / "demo.bit").stat().st_size} bytes; {len(saved)} changed inputs saved.',
                f'{len(logs)} simulation and {len(compile_logs)} compiler logs checked and retained.',
                'Unchanged production inputs reference v0.17.0-m5-local.1; two M6 cards are frozen below.',
                'Hardware fallback remains board-confirmed v0.16.0. M4 overall board feedback accepted; M1/M3 separate board, M5/M6 board and M2 visual confirmation pending.',
                'Timing audit exceptions equal M1. One added dummy-node model category: EG_PHY_BRAM32K, exactly FONT/TEXT ram.dob[9]; all other summary lines equal M1. Original known tool warnings preserved.',
                'TD E:/TD v6.2; ModelSim SE-64 10.6e F:/modelsim/win64; no file hashes.', '',
                'Local .gitattributes preserves original report, validation and source bytes (including tool-generated whitespace) without Git line-ending conversion.', '']
    manifest += [f'- {p.as_posix()} ({(ROOT / p).stat().st_size} bytes)' + (' [changed]' if p in saved else '')
                 for p in inputs]
    (release / 'MANIFEST.md').write_text('\n'.join(manifest)+'\n', encoding='utf-8')
    print(f'PASS M6 package: {release}; {len(inputs)} equal inputs, {len(logs)} passing simulations')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build')
    parser.add_argument('--candidate', default='m6-local.1')
    args = parser.parse_args()
    package(args.build, args.candidate)
