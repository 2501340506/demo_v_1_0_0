"""Read back actual M6 media, reproduce bytes, assemble negative cards in NEW output.

Does NOT claim RTL has consumed the full narration files or human listening review.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import struct
import wave

from PIL import Image
import yaml

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "tools/publicity/geohazard_release"


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def tree(path):
    return {p.relative_to(path).as_posix(): p.read_bytes() for p in path.rglob("*") if p.is_file()}


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def verify(out):
    out.mkdir(parents=True, exist_ok=False)
    pack = load("pack", ROOT / "tools/make_publicity_pack.py")
    card = load("card", ROOT / "tools/make_dual_mode_card.py")
    render = load("render", CONTENT / "render_inputs.py")
    records = []
    for slot in range(1, 5):
        with Image.open(CONTENT / f"inputs/page{slot}.png") as image:
            expected = image.convert("RGB").tobytes()
        with Image.open(CONTENT / f"generated/EDU{slot}.BMP") as image:
            check(image.size == (640, 480) and image.convert("RGB").tobytes() == expected, "BMP mismatch")
        with wave.open(str(CONTENT / f"inputs/narration{slot}.wav"), "rb") as wav:
            check(wav.getparams()[:3] == (1, 2, 48000), "Wrong WAV format")
            frames = wav.getnframes()
            pcm = wav.readframes(frames)
        check(pcm == (CONTENT / f"generated/VOI{slot}.PCM").read_bytes(), "PCM differs from WAV")
        count = peak = nonzero = clipped = 0
        for (value,) in struct.iter_unpack("<h", pcm):
            count += 1
            peak = max(peak, abs(value))
            nonzero += value != 0
            clipped += value in (-32768, 32767)
        check(count == frames and nonzero > 0 and clipped == 0, "Bad sample count, silence, or rail clipping")
        records.append(dict(slot=slot, bytes=len(pcm), samples=count, seconds=count / 48000,
                            peak=peak, nonzero=nonzero, rail_samples=clipped))
    frozen = tree(CONTENT / "generated")
    for i in (1, 2):
        pack.compile_pack(CONTENT / "pack.yaml", out / f"pack{i}")
        check(tree(out / f"pack{i}") == frozen, "Pack reproduction differs")
    rendering = render.renderer.generate(out / "render", Path("C:/Windows/Fonts/simhei.ttf"),
                                         CONTENT / "content.yaml", test_tones=False)
    for name, data in tree(out / "render").items():
        check((CONTENT / "inputs" / name).read_bytes() == data, "Raster reproduction differs")
    cards = []
    for short, scene in (("demo", "m6_demo"), ("flood", "flood_village")):
        record = card.assemble(ROOT / f"tools/scenes/{scene}/generated", CONTENT / "generated", out / short)
        # Manifest uses the CLI's path strings, while these inputs are absolute.
        # Compare every media byte, separately validate frozen manifest payload list.
        check(tree(out / short / "card") == tree(CONTENT / "cards" / short / "card"), "Full card differs")
        fixed = json.loads((CONTENT / "cards" / short / "manifest.json").read_text(encoding="utf-8"))
        check(record["files"] == fixed["files"] and record["bytes"] == fixed["bytes"], "Card manifest differs")
        cards.append(dict(name=short, files=len(record["files"]), bytes=record["bytes"]))
    negative = []
    base = tree(out / "demo" / "card")
    for variant in card.VARIANTS[1:]:
        record = card.assemble(ROOT / "tools/scenes/m6_demo/generated", CONTENT / "generated", out / variant,
                               variant, ROOT / "tools/publicity/geohazard_basics/generated/VOI1.PCM")
        changed = tree(out / variant / "card")
        different = sorted(k for k in base.keys() | changed.keys() if base.get(k) != changed.get(k))
        expected = sorted(card.EDU) if variant == "old_scene" else ["VOI1.PCM" if variant == "short_voice1" else "VOI2.PCM"]
        check(different == expected, "Unexpected negative-card changes")
        if variant == "odd_voice2":
            check(len(changed["VOI2.PCM"]) % 2 == 1 and changed["VOI2.PCM"][:-1] == base["VOI2.PCM"], "Bad odd fixture")
        if variant == "short_voice1":
            check(len(changed["VOI1.PCM"]) == 192000, "Expected two-second TEST TONE")
        negative.append(dict(variant=variant, files=len(record["files"]), changed=different))
    rejected = []
    try:
        card.assemble(ROOT / "tools/scenes/m6_demo/generated", CONTENT / "generated", out / "demo")
        raise AssertionError("Overwrite allowed")
    except ValueError:
        rejected.append("existing output")
    for bad in ("", {}, 4):
        config = yaml.safe_load((CONTENT / "pack.yaml").read_text(encoding="utf-8"))
        config["hardware_support"] = bad
        path = out / f"bad{len(rejected)}.yaml"
        path.write_text(yaml.safe_dump(config, allow_unicode=True), encoding="utf-8")
        destination = out / f"rejected{len(rejected)}"
        try:
            pack.compile_pack(path, destination)
            raise AssertionError("Invalid hardware metadata accepted")
        except ValueError:
            check(not destination.exists(), "Partial invalid output")
            rejected.append(f"invalid hardware_support: {type(bad).__name__}")
    result = dict(success=True, bmp_pixels=4 * 640 * 480, narration=records,
                  reproduced_pack_files=len(frozen), reproduced_pack_bytes=sum(map(len, frozen.values())),
                  reproduction_trees=2, raster_files=len(tree(out / "render")),
                  text_boxes=sum(len(p["text_bounds"]) for p in rendering["pages"]),
                  full_cards=cards, negative_cards=negative, rejected=rejected,
                  scope="Actual input/output PC bytes and formats; human content/listening and actual-media board acceptance pending")
    (out / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    verify(parser.parse_args().output)
