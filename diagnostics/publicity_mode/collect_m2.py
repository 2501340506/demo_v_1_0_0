"""Check completed M2 runs and save compact, reviewable evidence to a new folder."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
run, build, out = map(Path, sys.argv[1:])


def read_log(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


def write_evidence(path, content):
    # Keep raw tool logs in the run folder; normalize archived text whitespace.
    path.write_text("\n".join(line.rstrip() for line in content.splitlines()) + "\n",
                    encoding="utf-8", newline="\n")


names = [f"{top}_gap{gap}" for gap in (0, 2, 5) for top in (
    "tb_publicity_scan", "tb_publicity_reader", "tb_m5_scan_equivalence",
    "tb_snd_scan", "tb_audio_scan")]
names += [f"{top}_{case}" for case in range(42) for top in ("core", "reader_eq")]
names += [f"reader_eq_mode{mode}" for mode in range(1, 6)]
names += [f"reader_eq_scale{case}" for case in (0, 5, 6, 37)]
summary = [f"Input baseline: 8a90155; simulation: {run.name}; synthesis: {build.name}"]
compile_log = read_log(run / "compile.log")
assert "Errors: 0, Warnings: 0" in compile_log
assert not re.search(r"\*\* (?:Fatal|Error|Warning)", compile_log)
summary.append("PASS compile: Errors: 0, Warnings: 0")
for name in names:
    log = read_log(run / f"{name}.log")
    assert "Errors: 0, Warnings: 0" in log, name
    assert not re.search(r"\*\* (?:Fatal|Error|Warning)", log), name
    passes = re.findall(r"^# (PASS .*)$", log, re.M)
    assert passes, name
    summary.append(f"{name}: {'; '.join(passes)}; Errors: 0, Warnings: 0")
summary.append(f"PASS {len(names)} simulation/regression transcripts")
sources = []
for module, expected in (("fat32_volume_scanner", 1), ("fat32_bmp_reader", 10)):
    work = build / module
    log = read_log(work / "build.log")
    assert not re.search(r"\bERROR:", log), module
    assert "optimize_gate" in log
    files = [p for p in work.glob("*.v") if not p.stem.endswith("_enabled")]
    assert len(files) == expected
    for path in sorted(files):
        live = ROOT / "user_source/hdl_source/SD" / path.name
        assert live.read_bytes() == path.read_bytes(), str(live)
        sources.append(f"PASS {module}/{path.name}: {path.stat().st_size} bytes identical to active RTL")
    warnings = re.findall(r"^.*WARNING.*$", log, re.M)
    assert len(warnings) == (1 if module == "fat32_bmp_reader" else 0), warnings
    if warnings:
        assert "SYN-6562" in warnings[0] and "bmp_sector_buffer" in warnings[0]
    summary.append(f"PASS enabled standalone synthesis {module}; {expected} RTL files byte-identical; {len(warnings)} warnings; no production bit/PnR")
out.mkdir(parents=True, exist_ok=False)
write_evidence(out / "simulation_summary.txt", "\n".join(summary))
write_evidence(out / "source_comparison.txt", "\n".join(sources))
write_evidence(out / "compile.log", compile_log)
for gap in (0, 2, 5):
    for top in ("tb_publicity_scan", "tb_publicity_reader"):
        name = f"{top}_gap{gap}.log"
        write_evidence(out / name, read_log(run / name))
for module in ("fat32_volume_scanner", "fat32_bmp_reader"):
    for filename in ("build.log", "demo_gate.area"):
        write_evidence(out / f"{module}_{filename}", read_log(build / module / filename))
print(f"PASS {len(names)} transcripts, compile, two syntheses, 11 RTL snapshot comparisons; evidence {out}")
