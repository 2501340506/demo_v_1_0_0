"""Freeze verified M3 inputs and evidence; compare bytes, never hash files."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("m6_pack_checks", ROOT / "diagnostics/mountain_scene/package_m6.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
read_log, audit_summary = checks.read_log, checks.audit_summary


def check_log(path, marker=None):
    text = read_log(path)
    assert 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error)', text), path
    if marker:
        assert marker in text, (path, marker)
    for line in text.splitlines():
        if '** Warning:' in line:
            # ModelSim reports this testbench-only watchdog literal as signed.
            # It does not occur in RTL or TD. Keep the exact diagnostic visible.
            watchdog = (path.parent.name in ('publicity_m3_top_attempt04', 'publicity_m3_top_attempt05', 'publicity_m3_top_attempt06', 'publicity_m3_top_attempt07')
                        and path.name == 'compile.log' and 'tb_m3_top.sv(219)' in line
                        and "(vlog-2597) '3000000000' is being treated as 32-bit signed integer and will overflow." in line)
            assert checks.known_warning(line) or watchdog, (path, line)


def td_warnings(path):
    result = set()
    for line in read_log(path).splitlines():
        if re.search(r'WARNING|Warning|WARN-', line):
            line = re.sub(r'publicity_m3_td_attempt\d+|mountain(?:_scene)?_m[13456]_attempt\d+', 'BUILD', line)
            result.add(re.sub(r'\(\d+\)', '(line)', line).strip())
    return result


def package(build_name, config):
    output = ROOT / "diagnostics/output"
    build = output / build_name
    phy = build / "TD_project/demo_Runs/phy_1"
    release = ROOT / "releases/v0.18.0/m3-local.1"
    assert not release.exists(), "Never overwrite a candidate"
    timing = read_log(phy / "final_timing.rpt")
    margins = {}
    for field in ("SWNS", "HWNS", "STNS", "HTNS"):
        match = re.search(field + r":\s*([-\d.]+)ns", timing)
        assert match, field
        margins[field] = float(match[1])
        assert (margins[field] > 0 if field.endswith("WNS") else margins[field] == 0), margins
    area = read_log(phy / "demo_phy.area")
    lut = int(re.search(r"(?m)^#lut\s+(\d+)", area)[1])
    assert lut <= 16660, "LUT above 85% target"
    assert (phy / "demo.bit").stat().st_size == 673856
    for run in ("syn_1", "phy_1"):
        log = read_log(build / f"TD_project/demo_Runs/{run}/build_{build_name}.log")
        assert not re.search(r"\bERROR[: ]", log, re.I), run
        if run == "phy_1":
            assert "Generate bitstream completely" in log
    inputs = [Path("TD_project/demo.al")]
    inputs += [(ROOT / "TD_project" / p).resolve().relative_to(ROOT)
               for p in re.findall(r'<File Path="([^"]+)"', (ROOT / inputs[0]).read_text(encoding="utf-8"))]
    for name in inputs + [Path("diagnostics/run_td_build.ps1")]:
        assert (ROOT / name).read_bytes() == (build / name).read_bytes(), f"Build input differs: {name}"
    assert (ROOT / "问题小记录.txt").read_bytes() == (output / "publicity_m3_baseline01/personal_original.bin").read_bytes()

    logs = json.loads(config.read_text(encoding="utf-8"))
    assert logs, "No validation logs"
    for name, marker in logs.items():
        check_log(output / name, marker)
    compile_logs = []
    for folder in sorted({Path(n).parent for n in logs}):
        for path in sorted((output / folder).glob("*.log")):
            if "compile" in path.name or path.name in ("vendor.log", "encrypted.log", "pll.log"):
                check_log(path)
                compile_logs.append(path.relative_to(output))

    audit = build / "timing_audit"
    audit_text = read_log(audit / "check_timing.txt")
    dummy = re.search(r"DummyNode in Model: EG_PHY_BRAM32K\s+(.*?)\s+DummyNode in Model:", audit_text, re.S)
    assert dummy and set(dummy[1].split()) == {
        "g_scene_text$font_ram/ram.dob[9]", "g_scene_text$text_ram/ram.dob[9]"}
    prior_audit = ROOT / "releases/v0.17.0/m6-local.1/reports/check_timing.txt"
    assert audit_summary(audit / "check_timing.txt") == audit_summary(prior_audit), "Timing audit summary changed"
    warning_delta = {}
    for run in ('syn_1', 'phy_1'):
        current = td_warnings(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        prior = td_warnings(ROOT / f'releases/v0.17.0/m6-local.1/reports/{run}_build.log')
        warning_delta[run] = {'new': sorted(current - prior), 'gone': sorted(prior - current)}
        assert not warning_delta[run]['new'], f'New TD diagnostic: {run}: {warning_delta[run]}'

    def changed_since(ref):
        result = subprocess.check_output(["git", "diff", ref, "--name-only", "--", "user_source", "TD_project"], cwd=ROOT)
        return result.decode("utf-8").splitlines()
    m2_delta = changed_since("8e6bf69")
    hw_delta = changed_since("v0.17.0-m6-local.1")
    saved = [p for p in inputs if p.as_posix() in hw_delta]
    assert saved and set(m2_delta).issubset(hw_delta)
    release.mkdir(parents=True)
    (release / ".gitattributes").write_text(
        "** -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n"
        "reports/** -text -whitespace\nvalidation/** -text -whitespace\nsources/** -text -whitespace\n", encoding="utf-8")

    def copy(src, name):
        dst = release / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        assert src.read_bytes() == dst.read_bytes(), name

    copy(phy / "demo.bit", Path("demo.bit"))
    for name in ("final_timing.rpt", "demo_phy.area"):
        copy(phy / name, Path("reports") / name)
    for run in ("syn_1", "phy_1"):
        folder = build / "TD_project/demo_Runs" / run
        copy(folder / f"build_{build_name}.log", Path("reports") / f"{run}_build.log")
        copy(folder / "settings.cfg", Path("reports") / f"{run}_settings.cfg")
    for name in ("check_timing.txt", "audit.timing"):
        copy(audit / name, Path("reports") / name)
    (release / 'reports/warning_delta.json').write_text(json.dumps(warning_delta, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for name in list(logs) + compile_logs:
        copy(output / name, Path("validation") / name)
    copy(config, Path("validation/logs.json"))
    for name in saved:
        copy(ROOT / name, Path("sources") / name)
    for name in (Path("diagnostics/run_td_build.ps1"), Path("diagnostics/mountain_scene/build_m5.ps1"),
                 Path("diagnostics/publicity_mode/run_m3_audit.ps1")):
        copy(ROOT / name, Path("reproduce") / name)
    manifest = ["# M3 构建与源码清单", "", f"Build: {build_name}",
                f"{len(inputs)} 个工程输入及根构建脚本与隔离快照逐字节一致。",
                f"Bit: 673856 bytes; LUT {lut}/19600; timing {margins}.",
                f"{len(logs)} 份仿真及 {len(compile_logs)} 份编译日志；无文件哈希。",
                "仅备份相对硬件 M6 local.1 的变化输入，未改输入引用该标签；M2 差异单列。",
                "用户个人记录909字节与M3开始副本一致，未纳入交付。", "", "## M3 相对 M2", ""]
    manifest += [f"- {p}" for p in m2_delta]
    manifest += ["", "## 工程输入（相对硬件 M6 的变化标为 saved）", ""]
    manifest += [f"- {p.as_posix()} ({(ROOT / p).stat().st_size} bytes)" + (" [saved]" if p in saved else "") for p in inputs]
    (release / "MANIFEST.md").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print(f"PASS M3 package: {len(inputs)} equal inputs, {len(saved)} saved, {len(logs)} simulations, {len(compile_logs)} compiler logs; {margins}, LUT={lut}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build")
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    package(args.build, args.config)
