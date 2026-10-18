"""Draw original educational diagrams and TEST TONES, never formal narration.

Run: py -I -X utf8 .../make_inputs.py --output NEW --font C:/Windows/Fonts/simhei.ttf
The template, font and Pillow version define raster regeneration; frozen PNG/WAV
inputs are sufficient for pack reproduction without any font dependency.
"""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
import struct
import wave

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version
import yaml

INK = "#183344"
ACCENT = "#086d79"
PAPER = "#f4f6ed"
TONE_SECONDS = (2, 6, 8, 10)
TONE_PERIODS = (120, 100, 80, 64)
TOP = (0, 0, 640, 60)
AUDIO = (420, 210, 624, 412)


def tone(seconds, period):
    """Integer triangle wave, low amplitude, 10ms fade at both ends."""
    count = seconds * 48000
    raw = bytearray(count * 2)
    for n in range(count):
        phase = n % period
        value = (4 * 2400 * abs(phase - period // 2)) // period - 2400
        ramp = min(480, n, count - 1 - n)
        value = value * ramp // 480
        struct.pack_into("<h", raw, n * 2, value)
    stream = io.BytesIO()
    with wave.open(stream, "wb") as wav:
        wav.setparams((1, 2, 48000, count, "NONE", "not compressed"))
        wav.writeframes(raw)
    return stream.getvalue()


def generate(output, font_path, template=None, *, test_tones=True, bottom_waveform=False):
    output, font_path = Path(output), Path(font_path)
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    template = Path(template) if template else Path(__file__).with_name("content.yaml")
    spec = yaml.safe_load(template.read_text(encoding="utf-8"))
    fonts = {size: ImageFont.truetype(str(font_path), size) for size in (16, 20, 24, 32)}
    files, pages = {}, []
    for page in spec["pages"]:
        im = Image.new("RGB", (640, 480), PAPER)
        draw = ImageDraw.Draw(im)
        # These backgrounds intentionally carry no content under production OSD.
        draw.rectangle((0, 0, 639, 59), fill=INK)
        if not bottom_waveform:
            draw.rounded_rectangle(AUDIO, radius=18, fill="#e5ebe3")
        bounds = []

        def label(x, y, value, size=24, fill=INK):
            box = draw.textbbox((x, y), value, font=fonts[size])
            if not (0 <= box[0] < box[2] <= 640 and 60 <= box[1] < box[3] <= 480):
                raise ValueError(f"text outside page: {value}: {box}")
            reserved_regions = (TOP, (0, 420, 640, 480)) if bottom_waveform else (TOP, AUDIO)
            for reserved in reserved_regions:
                if max(box[0], reserved[0]) < min(box[2], reserved[2]) and max(box[1], reserved[1]) < min(box[3], reserved[3]):
                    raise ValueError(f"text overlaps OSD: {value}: {box}")
            draw.text((x, y), value, font=fonts[size], fill=fill)
            bounds.append({"text": value, "box": box, "font_px": size})

        label(24, 72, f"{page['id']:02d}  {page['title']}", 32)
        draw.line((24, 116, 616, 116), fill=ACCENT, width=3)
        kind = page["diagram"]
        if kind == "types":
            for x in (24, 224, 424):
                draw.polygon(((x, 196), (x+60, 130), (x+174, 196)), fill="#bdc8b1")
            draw.polygon(((91, 153), (125, 166), (151, 191), (115, 181)), fill="#ad643b")
            for x, y in ((303, 147), (322, 171), (344, 188)):
                draw.rectangle((x, y, x+10, y+9), fill="#785e4e")
            draw.line(((470, 145), (490, 167), (536, 185), (589, 190)), fill="#8a6249", width=13)
            label(34, 199, "滑坡", 20)
            label(234, 199, "崩塌", 20)
            label(434, 185, "泥石流", 20)
        elif kind == "signs":
            for x, name in ((24, "水流骤变"), (224, "夹带树木"), (424, "异常轰鸣")):
                draw.rounded_rectangle((x, 132, x+176, 200), radius=8, fill="#d8e7df")
                label(x+8, 150, name, 24, ACCENT)
        elif kind == "plan":
            for x, name in ((24, "当地预案"), (224, "确认路线"), (424, "集合清点")):
                draw.rounded_rectangle((x, 132, x+176, 174), radius=8, fill="#d8e7df")
                label(x+12, 140, name, 24, ACCENT)
                if x < 424:
                    draw.line((x+180, 152, x+194, 152), fill=ACCENT, width=3)
                    draw.polygon(((x+194, 152), (x+187, 146), (x+187, 158)), fill=ACCENT)
            label(24, 185, "教学流程示意；不是实际撤离地图", 20)
        elif kind == "prepare":
            for x, name in ((24, "联络"), (224, "物品"), (424, "演练")):
                draw.rounded_rectangle((x, 132, x+176, 200), radius=8, fill="#d8e7df")
                draw.rectangle((x+12, 150, x+34, 174), outline=ACCENT, width=3)
                draw.line(((x+16, 160), (x+22, 168), (x+31, 153)), fill=ACCENT, width=2)
                label(x+54, 151, name, 24, ACCENT)
        else:
            raise ValueError(f"unknown diagram: {kind}")
        for i, point in enumerate(page["points"]):
            label(24, 238 + i * 41, point, 24)
        label(24, 396 if bottom_waveform else 414, spec["disclaimer"], 20, "#a13c1d")
        if not bottom_waveform:
            label(24, 443, page["source"], 16)
            label(24, 462, spec["edition"], 16)
        stream = io.BytesIO()
        im.save(stream, format="PNG", optimize=False, compress_level=9)
        slot = page["id"]
        files[f"page{slot}.png"] = stream.getvalue()
        record = {"id": slot, "text_bounds": bounds}
        if test_tones:
            files[f"test_tone{slot}.wav"] = tone(TONE_SECONDS[slot-1], TONE_PERIODS[slot-1])
            record.update(test_tone_seconds=TONE_SECONDS[slot-1],
                          test_tone_hz=48000 // TONE_PERIODS[slot-1])
        pages.append(record)
    report = {"template_version": spec["version"], "pillow_version": pillow_version,
              "font_file": font_path.name, "font_bytes": font_path.stat().st_size,
              "formal_narration": False, "top_reserved": TOP,
              "audio_reserved": (0, 452, 640, 480) if bottom_waveform else AUDIO,
              "pages": pages}
    files["generation.json"] = (json.dumps(report, ensure_ascii=False, indent=2)+"\n").encode("utf-8")
    output.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        with (output / name).open("xb") as stream:
            stream.write(data)
        if (output / name).read_bytes() != data:
            raise ValueError(f"write mismatch: {name}")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--font", type=Path, required=True)
    args = parser.parse_args()
    try:
        generate(args.output, args.font)
    except (ValueError, OSError, KeyError, yaml.YAMLError) as error:
        parser.exit(2, f"error: {error}\n")
    print(f"{args.output}: four original pages and four TEST TONES; text bounds checked")


if __name__ == "__main__":
    main()
