"""Collect completed M6 regressions and prove exact M5 production-input/bit reuse."""
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "diagnostics/output"
RELEASE = ROOT / "releases/v0.18.0/m6-local.1"
spec = importlib.util.spec_from_file_location("m5", ROOT / "diagnostics/publicity_mode/package_m5.py")
m5 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m5)
SUITES = {
    "m5": "tb_m5_parameters tb_m5_scenario tb_m5_preview tb_m5_recovery tb_volume tb_adjust_cdc tb_adjust_keys tb_adjust_osd tb_adjust_decimal",
    "m4": "tb_m4_player tb_m4_auto tb_m4_stream tb_audio_stream tb_pcm_stream_player tb_audio_mux tb_m4_metadata",
    "unit": "tb_scenario tb_scenario_cdc tb_scene_fade tb_scene_keys tb_m5_scan tb_m5_loader tb_m6_text tb_frame_cache_control tb_transition_s1 tb_transition_wipe tb_transition_player tb_preview_control tb_preview_keys tb_preview_player tb_adjust tb_media_commit_cdc tb_media_player_control tb_pcm_production tb_pcm_preview_rescan tb_scenario_pcm tb_m5_loader_gap2 tb_m5_loader_gap5",
    "voice": "tb_m4_top", "pixels": "tb_m5_pixels", "status": "tb_m5_status",
    "legacy": "tb_scenario_top tb_m6_top", "system": "tb_cache_system", "preview": "tb_preview_system",
    **{f"mode{i}": "tb_m4_mode" for i in range(4)},
}


def main():
    records, compiler = [], []
    # Require every expected completion before copying evidence.
    for suite, tests in SUITES.items():
        folder = f"publicity_m6_final_{suite}_01"
        for test in tests.split():
            path = OUT / folder / f"{test}.log"
            m5.check_log(path, "PASS ")
            markers = [line.removeprefix("# ") for line in m5.checks.read_log(path).splitlines() if "PASS " in line]
            records.append(dict(path=f"{folder}/{path.name}", markers=markers))
        for name in ("compile", "vendor", "encrypted", "pll"):
            path = OUT / folder / f"{name}.log"
            m5.check_log(path)
            compiler.append(f"{folder}/{path.name}")
    inputs = [Path("TD_project/demo.al")]
    inputs += [(ROOT / "TD_project" / p).resolve().relative_to(ROOT)
               for p in re.findall(r'<File Path="([^"]+)"', (ROOT / inputs[0]).read_text(encoding="utf-8"))]
    frozen = OUT / "publicity_m5_td_attempt27"
    for name in inputs + [Path("diagnostics/run_td_build.ps1")]:
        assert (ROOT / name).read_bytes() == (frozen / name).read_bytes(), name
    assert (RELEASE / "demo.bit").read_bytes() == (ROOT / "releases/v0.18.0/m5-local.1/demo.bit").read_bytes()
    personal = ROOT / "问题小记录.txt"
    assert personal.read_bytes() == (OUT / "publicity_m6_baseline01/personal_original.bin").read_bytes()
    assert not subprocess.check_output(["git", "diff", "v0.18.0-m5-local.1", "--name-only", "--", "user_source", "TD_project"], cwd=ROOT).strip()
    validation = RELEASE / "validation"
    reuse = dict(baseline="v0.18.0-m5-board.1 / e49bb94; production bit f2d45c8",
                 engineering_inputs_equal=len(inputs),
                 inputs=[dict(path=p.as_posix(), bytes=(ROOT / p).stat().st_size) for p in inputs],
                 root_build_script_equal=True, candidate_bit_equal_to_m5=True,
                 bit_bytes=(RELEASE / "demo.bit").stat().st_size, personal_record_equal=True,
                 personal_bytes=personal.stat().st_size, td_rebuilt=False, rtl_changed=False)
    (validation / "reuse.json").write_text(json.dumps(reuse, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for record in records:
        source = OUT / record["path"]
        target = validation / record["path"]
        target.parent.mkdir(exist_ok=True)
        assert not target.exists(), target
        shutil.copyfile(source, target)
        assert source.read_bytes() == target.read_bytes()
    for name in compiler:
        target = validation / name
        assert not target.exists(), target
        shutil.copyfile(OUT / name, target)
        assert target.read_bytes() == (OUT / name).read_bytes()
    for source, name in ((OUT / "publicity_m6_pc01/verification.json", "pc.json"),
                         (OUT / "publicity_m6_media01/result.json", "media.json")):
        shutil.copyfile(source, validation / name)
    summary = dict(simulations=len(records), compiler_logs=len(compiler), results=records,
                   compiler=compiler, inherited_m5_simulations=183, inherited_m5_compiler_logs=69,
                   actual_m6_full_media_in_rtl=False,
                   scope="Current RTL protocol/output regressions use synthetic test vectors; actual M6 files fully compared on PC; actual card/HDMI/PCM/listening pending")
    (validation / "regression.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS M6: {len(records)} simulations; {len(compiler)} compiler/model logs; {len(inputs)} exact engineering inputs; original M5 bit unchanged")


if __name__ == "__main__":
    main()
