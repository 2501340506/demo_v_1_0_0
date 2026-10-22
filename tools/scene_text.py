"""M5 FONT/TEXT v1 encoder. No writes until all text and font checks pass."""
import re
import struct
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ESCAPES = "0123456789 :.-/!"
# Full-width forms of the escaped characters use the same codes.
FULLWIDTH = {chr(0xFF10 + d): str(d) for d in range(10)}
FULLWIDTH.update({"：": ":", "．": ".", "－": "-", "／": "/", "！": "!", "　": " "})


def glyph_char(c):
    """CJK ideographs and CJK/full-width punctuation are drawn as glyphs."""
    return 0x3400 <= ord(c) <= 0x9fff or 0x3000 <= ord(c) <= 0x303f or 0xff00 <= ord(c) <= 0xffef


def repo_root():
    """The repository root; a PyInstaller exe carries the font source it needs
    (build_annotate_exe.py --add-data) in its bundle folder."""
    if getattr(sys, "frozen", False):
        return Path(sys._MEIPASS)
    return Path(__file__).resolve().parents[1]


def find_face(spec):
    """SimSun for the drawn glyphs: spec["font"], else the C: drive copy used on
    the build machine (kept first so recorded metadata is unchanged there),
    else the Windows font by name."""
    candidates = [spec["font"]] if spec.get("font") else ["C:/Windows/Fonts/simsun.ttc", "simsun.ttc"]
    for name in candidates:
        try:
            return Path(name), ImageFont.truetype(str(Path(name)), 16)
        except OSError:
            pass
    raise ValueError("SimSun (simsun.ttc) not found; set text.font in scene.yaml")


def encode_text(spec, stages):
    if not isinstance(spec, dict):
        raise ValueError("text must be a mapping")
    titles = spec.get("titles", [s["name"] for s in stages])
    subtitles = spec.get("subtitles", [])
    normal = lambda s: "".join(FULLWIDTH.get(c, c) for c in s) if isinstance(s, str) else s
    titles, subtitles = [normal(s) for s in titles], [normal(s) for s in subtitles]
    if len(titles) != 4 or len(subtitles) != 4:
        raise ValueError("text needs four titles and four subtitles")
    segments = [v for pair in zip(titles, subtitles) for v in pair]
    segments += [normal(spec.get("warning", "")), normal(spec.get("village", ""))]
    if any(not isinstance(s, str) or len(s) > 31 for s in segments):
        raise ValueError("each text segment must contain at most 31 characters")
    # Preserve all original bit patterns, including the older hand drawn glyphs.
    source = repo_root() / "user_source/hdl_source/osd/osd_font_cn_16x16.v"
    matches = re.findall(r"8'h(8[0-9a-c]): bits = 256'([bh])([01a-f0-9]+);", source.read_text(encoding="utf-8"))
    if len(matches) != 13:
        raise ValueError("expected 13 fallback glyphs")
    font = bytearray().join(int(bits, 2 if radix == 'b' else 16).to_bytes(32, 'big')
                          for _, radix, bits in matches)
    slots = {"子": 3, "胆": 9, "肥": 10, "嘟": 11, "的": 12}
    new_chars = list(dict.fromkeys(c for s in segments for c in s if c not in ESCAPES and c not in slots))
    if len(new_chars) + 13 > 128:
        raise ValueError("FONT exceeds 128 glyphs")
    if any(not glyph_char(c) for c in new_chars):
        raise ValueError("text supports CJK characters, CJK punctuation and 0123456789 :.-/! only")
    face_path, face = find_face(spec) if new_chars else ("", None)
    for i, character in enumerate(new_chars, 13):
        slots[character] = i
        image = Image.new("1", (16, 16))
        ImageDraw.Draw(image).text((0, 0), character, font=face, fill=1)
        font.extend(image.tobytes())
    encoded = [bytes(0xf0 + ESCAPES.index(c) if c in ESCAPES else slots[c] for c in s)
               for s in segments]
    text = bytearray(b"TX\x01\x0a")
    offset = 44
    for i, data in enumerate(encoded):
        kind = i % 2 if i < 8 else i - 6
        text.extend(struct.pack("<HBB", offset, len(data), kind))
        offset += len(data)
    text.extend(b"".join(encoded))
    if len(font) > 4096 or len(text) > 4096:
        raise ValueError("FONT/TEXT exceeds 4096 bytes")
    return bytes(font), bytes(text), {"segments": segments, "slots": slots,
        "font_bytes": len(font), "text_bytes": len(text),
        "font_source": str(face_path), "font_origin": "SimSun 16px (0,0); first 13 exact case glyphs",
        "escapes": ESCAPES, "segment_order": "stage title/subtitle x4, warning, village"}
