"""Scene image/audio compiler. Run with py -I; see scenes/README.md."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import struct
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw
import yaml


HAZARD = ((0, 0, 0), (96, 48, 16), (0, 96, 224), (0, 192, 64))
FRONT = ((0, 0, 0), (255, 224, 0), (255, 255, 255), (0, 255, 0))
TIMES = (0, 120, 239)
PHASES = {"bright": (True, True), "dark": (False, False)}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def image_array(path, mode, size):
    with Image.open(path) as image:
        require(image.size == size, f"{path}: expected {size}, got {image.size}")
        return np.array(image.convert(mode), dtype=np.uint8)


def coverage(spec, folder, size):
    if "mask" in spec:
        return image_array(folder / spec["mask"], "L", size) > 0
    return np.ones((size[1], size[0]), dtype=bool)


def point(value, size):
    require(isinstance(value, (list, tuple)) and len(value) == 2, "point must be [x,y]")
    x, y = map(float, value)
    require(math.isfinite(x) and math.isfinite(y) and
            0 <= x < size[0] and 0 <= y < size[1], f"point outside image: {value}")
    return x, y


def gray_times(spec, folder, size):
    path = folder / spec["path"]
    gray = image_array(path, "L", size).astype(np.uint16)
    active = coverage(spec, folder, size)
    # Alpha is a coverage mask only; grayscale controls arrival time.
    with Image.open(path) as image:
        if "A" in image.getbands() or "transparency" in image.info:
            active &= np.array(image.convert("RGBA"))[:, :, 3] > 0
    return np.where(active, gray * 239 // 255, 255).astype(np.uint8)


def polyline_times(spec, size):
    points = [point(p, size) for p in spec["points"]]
    require(len(points) >= 2, "polyline needs at least two points")
    width = float(spec.get("width", 5))
    require(math.isfinite(width) and width > 0, "polyline width must be positive")
    start, end = spec.get("start", 0), spec.get("end", 239)
    require(isinstance(start, int) and isinstance(end, int) and
            0 <= start <= end <= 239, "polyline start/end must be integers in 0..239")
    lengths = [math.hypot(b[0] - a[0], b[1] - a[1])
               for a, b in zip(points, points[1:])]
    total = sum(lengths)
    require(total > 0, "polyline has zero total length")
    yy, xx = np.indices((size[1], size[0]), dtype=np.float64)
    best = np.full(xx.shape, np.inf)
    along = np.zeros(xx.shape)
    offset = 0.0
    for a, b, length in zip(points, points[1:], lengths):
        if length == 0:
            continue
        dx, dy = b[0] - a[0], b[1] - a[1]
        u = np.clip(((xx - a[0]) * dx + (yy - a[1]) * dy) / length**2, 0, 1)
        distance = (xx - a[0] - u * dx)**2 + (yy - a[1] - u * dy)**2
        nearer = distance < best  # Equal-distance crossings keep the first segment.
        along[nearer] = offset + u[nearer] * length
        best[nearer] = distance[nearer]
        offset += length
    quantized = np.floor(start + (end - start) * along / total + 1e-9)
    return np.where(best <= (width / 2)**2, quantized, 255).astype(np.uint8)


def chamfer_distance(seeds):
    """Two-pass 3/4 chamfer; return integer costs, orthogonal step = 3."""
    h, w = seeds.shape
    distance = np.where(seeds, 0, 3 * (w + h) + 1).astype(np.int32)
    for y in range(h):
        for x in range(w):
            d = int(distance[y, x])
            if x:
                d = min(d, int(distance[y, x - 1]) + 3)
            if y:
                d = min(d, int(distance[y - 1, x]) + 3)
                if x:
                    d = min(d, int(distance[y - 1, x - 1]) + 4)
                if x + 1 < w:
                    d = min(d, int(distance[y - 1, x + 1]) + 4)
            distance[y, x] = d
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            d = int(distance[y, x])
            if x + 1 < w:
                d = min(d, int(distance[y, x + 1]) + 3)
            if y + 1 < h:
                d = min(d, int(distance[y + 1, x]) + 3)
                if x:
                    d = min(d, int(distance[y + 1, x - 1]) + 4)
                if x + 1 < w:
                    d = min(d, int(distance[y + 1, x + 1]) + 4)
            distance[y, x] = d
    return distance


def seed_times(spec, folder, size):
    seeds = np.zeros((size[1], size[0]), dtype=bool)
    for p in spec.get("points", []):
        x, y = point(p, size)
        require(x.is_integer() and y.is_integer(), "seed coordinates must be integers")
        seeds[int(y), int(x)] = True
    if "seed_mask" in spec:
        seeds |= image_array(folder / spec["seed_mask"], "L", size) > 0
    require(seeds.any(), "seeds source is empty")
    radius = float(spec["max_distance"])
    require(math.isfinite(radius) and radius > 0, "max_distance must be positive")
    distance = chamfer_distance(seeds)
    # max_distance is in orthogonal pixels; the mask clips coverage afterwards.
    t = np.floor(distance.astype(np.float64) * 239 / (radius * 3))
    return np.where(distance <= radius * 3, t, 255).astype(np.uint8)


def make_times(stage, scene, folder, size):
    result = np.full((size[1], size[0]), 255, dtype=np.uint8)
    for spec in stage.get("sources", []):
        kind = spec["type"]
        if kind == "grayscale":
            times = gray_times(spec, folder, size)
        elif kind == "polyline":
            times = polyline_times(spec, size)
        elif kind == "seeds":
            times = seed_times(spec, folder, size)
        else:
            raise ValueError(f"unknown T source: {kind}")
        times = np.where(coverage(spec, folder, size), times, 255).astype(np.uint8)
        result = np.minimum(result, times)
    yy, xx = np.indices(result.shape)
    for spot in scene.get("safe_spots", []) + stage.get("safe_spots", []):
        x, y = point(spot["center"], size)
        radius = float(spot.get("radius", 6))
        require(math.isfinite(radius) and radius >= 0, "safe spot radius must be nonnegative")
        result[(xx - x)**2 + (yy - y)**2 <= radius**2] = 250
    require(np.all((result <= 239) | (result == 250) | (result == 255)), "reserved T generated")
    return result


def hazard_reference(rgb, times, stage, t_now, blink_fast=False, blink_slow=False,
                     enable=True, thumbnail=False):
    """RGB before brightness/contrast, stage=0..3, unsigned full-sum rounding."""
    require(stage in range(4) and t_now in range(240), "stage/t_now outside range")
    out = np.array(rgb, dtype=np.uint8, copy=True)
    require(out.shape == (*times.shape, 3), "RGB/T shape mismatch")
    if not enable or thumbnail:
        return out
    base = out.astype(np.uint16)
    if stage != 0:  # Stage 1 rainfall has no hazard tint or front.
        covered = (times < 240) & (times <= t_now)
        front = covered & ((t_now - times.astype(np.int16)) < 6)
        color = np.array(HAZARD[stage], dtype=np.uint16)
        mixed = ((base + color) >> 1) if stage == 2 else ((base + 3 * color) >> 2)
        out[covered] = mixed[covered].astype(np.uint8)
        if blink_fast:
            out[front] = FRONT[stage]
        else:
            out[front] = ((base + 3 * color) >> 2)[front].astype(np.uint8)
    if blink_slow:
        out[times == 250] = (0, 255, 0)
    return out


def write_bmp32(path, rgb, times):
    h, w = times.shape
    payload = np.empty((h, w, 4), dtype=np.uint8)
    payload[:, :, :3] = rgb[:, :, ::-1]
    payload[:, :, 3] = times
    size = 54 + w * h * 4
    header = struct.pack("<2sIHHI", b"BM", size, 0, 0, 54)
    header += struct.pack("<IiiHHIIiiII", 40, w, h, 1, 32, 0, w*h*4, 0, 0, 0, 0)
    path.write_bytes(header + payload[::-1].tobytes())


def read_bmp32(path):
    """Read raw BI_RGB bytes: Pillow can discard the fourth byte of this format."""
    raw = path.read_bytes()
    require(len(raw) >= 54, f"{path}: truncated header")
    signature, size, r1, r2, offset = struct.unpack_from("<2sIHHI", raw)
    dib, w, h, planes, bits, compression, data_size, _, _, used, important = \
        struct.unpack_from("<IiiHHIIiiII", raw, 14)
    require(signature == b"BM" and size == len(raw) and r1 == r2 == 0, "invalid BMP file header")
    require(dib == 40 and planes == 1 and bits == 32 and compression == 0,
            "BMP must use 40-byte DIB, planes=1, 32bpp, BI_RGB")
    require(w > 0 and h > 0 and ((w <= 1920 and h <= 1080) or (w <= 1080 and h <= 1920)),
            "BMP dimensions outside FPGA range")
    require(offset == 54 and used == important == 0 and
            data_size == w*h*4 and size == offset + data_size, "invalid BMP bounds")
    rows = np.frombuffer(raw, dtype=np.uint8, offset=offset).reshape(h, w, 4)
    rgba = rows[::-1].copy()
    rgba[:, :, :3] = rgba[:, :, 2::-1].copy()
    return rgba[:, :, :3], rgba[:, :, 3]


def save_png(path, array):
    Image.fromarray(array).save(path)


def contact_sheet(folder):
    sheet = Image.new("RGB", (6 * 256, 4 * 216), "#edf1f4")
    draw = ImageDraw.Draw(sheet)
    for stage in range(1, 5):
        for column, (t, phase) in enumerate((t, p) for t in TIMES for p in PHASES):
            name = f"PIC{stage}_t{t:03}_{phase}.png"
            with Image.open(folder / "expected" / name) as image:
                sheet.paste(image.resize((256, 192), Image.Resampling.NEAREST), (column*256, (stage-1)*216))
            draw.text((column*256 + 6, (stage-1)*216 + 196),
                      f"stage {stage} | t={t} | {phase}", fill="#162c3c")
    sheet.save(folder / "overview.png")


def build(scene_path, output=None):
    scene_path = Path(scene_path).resolve()
    folder = scene_path.parent
    scene = yaml.safe_load(scene_path.read_text(encoding="utf-8"))
    require(isinstance(scene, dict) and scene.get("version") == 1, "scene.yaml version must be 1")
    require("text" not in scene, "text output is planned for M5")
    audio = scene.get("audio", [])
    require(isinstance(audio, list) and len(audio) in (0, 4), "audio must list four stage source paths")
    for source in audio:
        require(isinstance(source, str) and (scene_path.parent / source).is_file(), f"missing audio source: {source}")
    stages = scene["stages"]
    require(len(stages) == 4 and [s["id"] for s in stages] == [1, 2, 3, 4], "need stages 1,2,3,4 in order")
    # Validate every source before creating the output directory.
    frames = []
    for stage in stages:
        base = folder / stage.get("base", scene["base"])
        with Image.open(base) as image:
            size = image.size
        w, h = size
        require(w > 0 and h > 0 and ((w <= 1920 and h <= 1080) or (w <= 1080 and h <= 1920)),
                f"{base}: dimensions outside FPGA range")
        # M3 vectors describe source pixels; demo is exactly 640x480 (no scaling).
        rgb = image_array(base, "RGB", size)
        frames.append((rgb, make_times(stage, scene, folder, size)))
    out = Path(output).resolve() if output else (folder / scene["output"]).resolve()
    require(not out.exists(), f"output already exists (preserved): {out}")
    out.mkdir(parents=True)
    (out / "expected").mkdir()
    (out / "diagnostics").mkdir()
    records = []
    for i, (rgb, times) in enumerate(frames, 1):
        bmp = out / f"PIC{i}.BMP"
        write_bmp32(bmp, rgb, times)
        saved_rgb, saved_t = read_bmp32(bmp)
        require(np.array_equal(saved_rgb, rgb) and np.array_equal(saved_t, times), f"PIC{i}: readback mismatch")
        save_png(out / "diagnostics" / f"PIC{i}_rgb.png", saved_rgb)
        save_png(out / "diagnostics" / f"PIC{i}_T.png", saved_t)
        for t in TIMES:
            for phase, (fast, slow) in PHASES.items():
                expected = hazard_reference(saved_rgb, saved_t, i-1, t, fast, slow)
                path = out / "expected" / f"PIC{i}_t{t:03}_{phase}.png"
                save_png(path, expected)
                require(np.array_equal(image_array(path, "RGB", bmp_dimensions(saved_t)), expected),
                        f"{path}: PNG readback mismatch")
        values, counts = np.unique(saved_t, return_counts=True)
        records.append({"file": bmp.name, "bytes": bmp.stat().st_size,
                        "width": rgb.shape[1], "height": rgb.shape[0],
                        "t_histogram": {str(int(v)): int(n) for v, n in zip(values, counts)}})
    contact_sheet(out)
    audio_records = []
    for index, source in enumerate(audio, 1):
        destination = out / f"SND{index}.PCM"
        subprocess.run([sys.executable, "-I", str(Path(__file__).with_name("make_audio_corpus.py")),
                        str(scene_path.parent / source), str(destination)], check=True)
        size = destination.stat().st_size
        require(size > 0 and size % 2 == 0, f"invalid PCM output: {destination}")
        audio_records.append({"file": destination.name, "source": source, "bytes": size,
                              "samples": size // 2, "seconds": size / 96000})
    manifest = {"format": "M4-images-audio-v1" if audio else "M2-images-v1", "scene": scene.get("name", scene_path.stem),
                "bmp_readback": "all RGB/T bytes equal", "expected_png_readback": "24/24 equal",
                "stage_index": "PIC1..4 corresponds to RTL stage 0..3",
                "reference": {"hazard_rgb": HAZARD, "front_rgb": FRONT, "front_width": 6,
                              "mix": "floor((rgb + k*hazard)/(k+1)); k=1 or 3",
                              "times": TIMES, "phases_fast_slow": PHASES},
                "files": records, "audio": audio_records,
                "audio_format": "48000 Hz mono signed 16-bit little-endian",
                "board_validation": "pending", "visual_confirmation": "pending"}
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {out}: 4 BI_RGB BMPs, all RGB/T bytes read back, 24 expected PNGs read back")
    return manifest


def bmp_dimensions(times):
    return times.shape[1], times.shape[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene", type=Path, help="scene.yaml")
    parser.add_argument("--output", type=Path, help="new output directory; overrides YAML output")
    args = parser.parse_args()
    try:
        build(args.scene, args.output)
    except (ValueError, KeyError, TypeError, OSError, yaml.YAMLError) as error:
        parser.exit(2, f"scene pack: {error}\n")


if __name__ == "__main__":
    main()
