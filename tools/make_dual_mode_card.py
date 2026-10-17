"""Assemble a NEW FAT32-root directory; never writes to a drive/card directly.

py -I -X utf8 tools/make_dual_mode_card.py --scene tools/scenes/m6_demo/generated \
 --publicity tools/publicity/geohazard_release/generated --output NEW
Copy only NEW/card/* to the FAT32 root. Manifest stays outside card/.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct

SCENE = [f"PIC{i}.BMP" for i in range(1, 5)] + [f"SND{i}.PCM" for i in range(1, 5)] + ["FONT.BIN", "TEXT.BIN"]
EDU = [f"EDU{i}.BMP" for i in range(1, 5)] + [f"VOI{i}.PCM" for i in range(1, 5)]
VARIANTS = ("full", "missing_voice2", "odd_voice2", "old_scene", "short_voice1")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def assemble(scene, publicity, output, variant="full", short_pcm=None):
    scene, publicity, output = map(Path, (scene, publicity, output))
    require(not output.exists(), f"Output already exists: {output}")
    require(variant in VARIANTS, "Unknown variant")
    manifest = json.loads((publicity / "manifest.json").read_text(encoding="utf-8"))
    files = {name: (scene / name).read_bytes() for name in SCENE}
    if variant != "old_scene":
        files.update({name: (publicity / name).read_bytes() for name in EDU})
    for name, data in files.items():
        require(data, f"Empty input: {name}")
        if name.endswith(".BMP"):
            width, height, planes, bpp, compression = struct.unpack_from("<iiHHI", data, 18)
            require(data[:2] == b"BM" and (width, height, planes, compression) == (640, 480, 1, 0)
                    and bpp in (24, 32) and len(data) == 54 + 640 * 480 * bpp // 8,
                    f"Unsupported BMP: {name}")
        if name.endswith(".PCM"):
            require(len(data) % 2 == 0 and not data.startswith(b"RIFF"), f"Not raw s16le: {name}")
    if variant != "old_scene":
        for page in manifest["pages"]:
            require(page["audio_status"] == "narration_unreviewed", "M6 requires speech inputs, pending review")
            require(page["pcm_bytes"] == len(files[page["pcm"]]), "Publicity manifest size mismatch")
    notes = []
    if variant == "missing_voice2":
        files.pop("VOI2.PCM")
        notes.append("VOI2 absent intentionally: silence, N state, five-second AUTO fallback")
    elif variant == "odd_voice2":
        files["VOI2.PCM"] += b"\x01"
        notes.append("VOI2 odd bytes intentionally: reject, E state, five-second AUTO fallback")
    elif variant == "old_scene":
        notes.append("Scene-only PIC/SND/FONT/TEXT old-format card: COMPAT; no EDU/VOI or BGM")
    elif variant == "short_voice1":
        require(short_pcm is not None, "Provide --short-pcm (explicit TEST TONE)")
        data = Path(short_pcm).read_bytes()
        require(0 < len(data) < 5 * 48000 * 2 and len(data) % 2 == 0
                and not data.startswith(b"RIFF"), "Short test PCM must be <5s raw s16le")
        files["VOI1.PCM"] = data
        notes.append("VOI1 replaced by <5-second TEST TONE; NOT narration listening acceptance")
    record = {"format": "M6-dual-mode-card-v1", "content_version": manifest["content_version"],
              "variant": variant, "scene": scene.as_posix(), "publicity": publicity.as_posix(),
              "files": [{"name": name, "bytes": len(data)} for name, data in sorted(files.items())],
              "bytes": sum(map(len, files.values())), "notes": notes,
              "review": "Content, synthetic narration and actual board measurements pending",
              "usage": "Copy card/* only to FAT32 root; replace card while powered off, then reset"}
    (output / "card").mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        with (output / "card" / name).open("xb") as stream:
            stream.write(data)
        require((output / "card" / name).read_bytes() == data, f"Readback differs: {name}")
    (output / "manifest.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--publicity", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=VARIANTS, default="full")
    parser.add_argument("--short-pcm", type=Path)
    args = parser.parse_args()
    try:
        result = assemble(args.scene, args.publicity, args.output, args.variant, args.short_pcm)
    except (OSError, ValueError, KeyError, struct.error) as error:
        parser.exit(2, f"error: {error}\n")
    print(f"{args.output}: {len(result['files'])} media files, {result['bytes']} bytes, {args.variant}; byte readback passed")
