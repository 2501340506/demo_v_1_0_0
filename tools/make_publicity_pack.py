"""Compile four publicity pages. Run with py -I -X utf8; see publicity/README.md."""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
import struct
import wave

from PIL import Image
import yaml

SIZE = (640, 480)
RATE = 48000
TOOL_VERSION = 1


def require(condition, message):
    if not condition:
        raise ValueError(message)


def text(path):
    value = path.read_text(encoding="utf-8").strip()
    require(value and "\ufffd" not in value, f"empty or invalid UTF-8 text: {path}")
    return value


def bmp24(image):
    # Fixed width has no padding; positive height means bottom-up BI_RGB.
    pixels = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes("raw", "BGR")
    return (struct.pack("<2sIHHI", b"BM", 54 + len(pixels), 0, 0, 54)
            + struct.pack("<IiiHHIIiiII", 40, *SIZE, 1, 24, 0, len(pixels), 0, 0, 0, 0)
            + pixels)


def read_bmp24(payload):
    require(len(payload) == 921654, "BMP must contain exactly 640x480 RGB888 pixels")
    magic, size, reserved1, reserved2, offset = struct.unpack_from("<2sIHHI", payload)
    dib, width, height, planes, bpp, compression, pixels = struct.unpack_from("<IiiHHII", payload, 14)
    require((magic, size, reserved1, reserved2, offset, dib, width, height,
             planes, bpp, compression, pixels)
            == (b"BM", len(payload), 0, 0, 54, 40, 640, 480, 1, 24, 0, 921600),
            "invalid BMP header")
    return Image.frombytes("RGB", SIZE, payload[54:], "raw", "BGR", 0, -1)


def wav_pcm(path):
    # Same exact-format extraction as make_audio_corpus.py. No ffmpeg fallback
    # here: unsupported input must fail explicitly, rather than silently resample.
    require(path.suffix.lower() == ".wav", "audio input must be a WAV file")
    raw = path.read_bytes()
    require(len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", "invalid RIFF/WAVE header")
    end = struct.unpack_from("<I", raw, 4)[0] + 8
    require(end == len(raw), "RIFF size differs from actual WAV bytes")
    position, data_size = 12, None
    # wave.getnframes() floors odd data sizes. Inspect the actual declared chunk
    # length first so a trailing half-sample cannot disappear during extraction.
    while position + 8 <= end:
        kind, size = struct.unpack_from("<4sI", raw, position)
        position += 8
        require(position + size <= end, "truncated WAV chunk")
        if kind == b"data":
            require(data_size is None, "multiple WAV data chunks are not supported")
            require(size > 0 and size % 2 == 0, "empty or odd-length WAV data chunk")
            data_size = size
        position += size + (size % 2)
    require(position == end and data_size is not None, "invalid WAV chunk layout")
    with wave.open(str(path), "rb") as wav:
        require((wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype())
                == (1, 2, RATE, "NONE"), "WAV must be uncompressed 48kHz mono signed 16-bit")
        count = wav.getnframes()
        payload = wav.readframes(count)
    require(count > 0 and len(payload) == count * 2 == data_size and len(payload) % 2 == 0,
            "empty, truncated or odd-length WAV data")
    return payload


def png_bytes(image):
    stream = io.BytesIO()
    image.save(stream, format="PNG", optimize=False, compress_level=9)
    return stream.getvalue()


def compile_pack(config, output):
    config, output = Path(config), Path(output)
    require(not output.exists(), f"output already exists (never overwritten): {output}")
    spec = yaml.safe_load(text(config))
    require(isinstance(spec, dict) and spec.get("version") == 1, "expected config version: 1")
    require(isinstance(spec.get("name"), str) and spec["name"].strip(), "name is required")
    require(isinstance(spec.get("content_version"), str) and spec["content_version"].strip(),
            "content_version is required")
    pages = spec.get("pages")
    require(isinstance(pages, list) and len(pages) == 4, "exactly four pages required")
    require(all(isinstance(p, dict) and type(p.get("id")) is int for p in pages)
            and [p["id"] for p in pages] == [1, 2, 3, 4], "page ids must be ordered 1,2,3,4")
    folder = config.parent
    files, records, images = {}, [], []
    for page in pages:
        slot = page["id"]
        for key in ("image", "script", "title"):
            require(isinstance(page.get(key), str) and page[key].strip(), f"page {slot}: missing {key}")
        require("audio" in page, f"page {slot}: audio must be a WAV path or explicit null")
        refs = page.get("source_refs")
        require(isinstance(refs, list) and refs and all(isinstance(r, str) for r in refs),
                f"page {slot}: source_refs required")
        sources = [{"path": ref, "record": text(folder / ref)} for ref in refs]
        script = text(folder / page["script"])
        with Image.open(folder / page["image"]) as source:
            require(source.size == SIZE, f"page {slot}: image must be 640x480, no implicit resizing")
            require(source.mode == "RGB", f"page {slot}: image must be opaque RGB (no alpha/palette)")
            image = source.copy()
        bmp_name, pcm_name = f"EDU{slot}.BMP", f"VOI{slot}.PCM"
        files[bmp_name] = bmp24(image)
        require(read_bmp24(files[bmp_name]).tobytes() == image.tobytes(), "BMP readback mismatch")
        preview = f"previews/EDU{slot}.png"
        files[preview] = png_bytes(image)
        images.append(image)
        audio_path = page["audio"]
        if audio_path is None:
            require(page.get("audio_status") == "missing", "null audio requires audio_status: missing")
            pcm, status = b"", "missing"
        else:
            require(isinstance(audio_path, str) and audio_path, "audio must be a WAV path or null")
            status = page.get("audio_status")
            require(status in ("test_tone", "narration_unreviewed"),
                    "audio_status must be test_tone or narration_unreviewed; M1 does not certify narration")
            pcm = wav_pcm(folder / audio_path)
            files[pcm_name] = pcm
        records.append({
            "id": slot, "title": page["title"], "image_input": page["image"],
            "bmp": bmp_name, "bmp_bytes": len(files[bmp_name]), "preview": preview,
            "script_input": page["script"], "script": script, "source_refs": sources,
            "audio_input": audio_path, "audio_status": status,
            "pcm": pcm_name if pcm else None, "pcm_bytes": len(pcm),
            "pcm_samples": len(pcm) // 2, "duration_seconds": len(pcm) / (2 * RATE),
            "audio_matches_script": False if status == "test_tone" else None,
            "note": "Test tones contain no speech." if status == "test_tone"
                    else "No voice; five-second fallback is a future hardware requirement." if status == "missing"
                    else "Narration requires full listening review against the script.",
        })
    overview = Image.new("RGB", (1280, 960))
    for i, image in enumerate(images):
        overview.paste(image, ((i % 2) * 640, (i // 2) * 480))
    files["previews/overview.png"] = png_bytes(overview)
    manifest = {
        "tool_version": TOOL_VERSION, "config_version": spec["version"],
        "name": spec["name"], "content_version": spec["content_version"],
        "content_review": "pending_human_review", "formal_narration": False,
        "image_format": "640x480 RGB888 bottom-up BMP BI_RGB; 24bpp",
        "audio_format": "48000Hz mono signed s16le raw PCM (no WAV header)",
        "minimum_display_seconds_target": 5, "hardware_support": "pending M2-M5; M1 is PC-only",
        "layout": spec.get("layout", {}), "pages": records,
        "files": [{"path": name, "bytes": len(data)} for name, data in sorted(files.items())],
    }
    files["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    # Validate all inputs before creating anything. Partial I/O failures are left
    # visible for diagnosis; a retry always uses a fresh output directory.
    output.mkdir(parents=True, exist_ok=False)
    for name, payload in files.items():
        destination = output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as stream:
            stream.write(payload)
        require(destination.read_bytes() == payload, f"written bytes differ: {name}")
    for page, image in zip(records, images):
        require(read_bmp24((output / page["bmp"]).read_bytes()).tobytes() == image.tobytes(),
                "on-disk BMP readback mismatch")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--output", type=Path, required=True, help="must not already exist")
    args = parser.parse_args()
    try:
        manifest = compile_pack(args.config, args.output)
    except (ValueError, OSError, KeyError, EOFError, wave.Error, yaml.YAMLError) as error:
        parser.exit(2, f"error: {error}\n")
    print(f"{args.output}: four BMP pages, {sum(p['pcm'] is not None for p in manifest['pages'])} PCM files; "
          "readback passed; human content/audio review pending")


if __name__ == "__main__":
    main()
