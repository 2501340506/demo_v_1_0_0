"""Generate PS1 full narration, fixed glyph ROM and independent test vectors.

PS1: 'PS', version=1, pages=4; four <HHHHH> descriptors (byte offset,
character count, pixels/frame Q8, audio frames, glyph count); LE16 glyph IDs.
The video clock is 25 MHz and each frame is 800*525 clocks.
"""
import argparse
import json
import math
import struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
MARKER = '// BEGIN GENERATED PUBLICITY FONT\n'


def generate(out, update_rtl=False):
    base = ROOT / 'tools/publicity/geohazard_release'
    scripts = [(base / f'scripts/page{i}.txt').read_text(encoding='utf-8').strip()
               for i in range(1, 5)]
    glyphs = list(dict.fromkeys(''.join(scripts)))
    assert len(glyphs) == 276
    face = ImageFont.truetype('C:/Windows/Fonts/simsun.ttc', 16)
    rows = []
    for char in glyphs:
        im = Image.new('1', (16, 16))
        ImageDraw.Draw(im).text((0, 0), char, font=face, fill=1)
        rows.extend(struct.unpack('>16H', im.tobytes()))
    codes = [[glyphs.index(c) for c in s] for s in scripts]
    text = bytearray(b'PS\x01\x04')
    offset = 44
    pages = []
    for i, (script, ids) in enumerate(zip(scripts, codes), 1):
        pcm = base / f'generated/VOI{i}.PCM'
        samples = pcm.stat().st_size // 2
        # Integer arithmetic: enough frames for the full PCM duration.
        frames = (samples * 25000000 + 48000*420000-1) // (48000*420000)
        end = (624 + len(ids)*16) * 256
        step = (end + frames-1) // frames
        assert 0 < len(ids) <= 255 and 0 < step < 1024 and frames < 4096
        text.extend(struct.pack('<HHHHH', offset, len(ids), step, frames, len(glyphs)))
        pages.append(dict(page=i, text=script, characters=len(ids), offset=offset,
                          pcm_bytes=samples*2, seconds=samples/48000,
                          frames=frames, step_q8=step,
                          scroll_frames=math.ceil(end/step)))
        offset += len(ids)*2
    for ids in codes:
        text.extend(struct.pack('<'+'H'*len(ids), *ids))
    assert len(text) == offset and offset <= 4096
    # Decode everything independently of the forward list construction.
    for page in pages:
        at, count, step, frames, ng = struct.unpack_from('<HHHHH', text, 4+(page['page']-1)*10)
        restored = ''.join(glyphs[c[0]] for c in struct.iter_unpack('<H', text[at:at+count*2]))
        assert restored == page['text'] and ng == len(glyphs)
    out.mkdir(parents=True, exist_ok=True)
    (out/'card').mkdir(exist_ok=True)
    (out/'card/TEXT.BIN').write_bytes(text)
    (out/'text_words.hex').write_text(''.join(f'{v[0]:04x}\n' for v in struct.iter_unpack('<H', text)), encoding='ascii')
    (out/'font_rows.hex').write_text(''.join(f'{v:04x}\n' for v in rows), encoding='ascii')
    manifest = dict(format='PS1', text_bytes=len(text), glyphs=''.join(glyphs),
                    font='SimSun 16px (0,0), rendered glyphs only',
                    video_clock_hz=25000000, clocks_per_frame=420000,
                    caption_window=[8,424,631,439], band=[0,420,639,443],
                    waveform=[0,452,639,479], pages=pages)
    (out/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    rom = MARKER + '// Regenerate with tools/publicity/make_narration_subtitles.py --update-rtl\n'
    rom += 'module publicity_narration_font(input clk,input [12:0] address,output reg [15:0] data);\n'
    rom += '(* syn_romstyle = "block_rom" *) reg [15:0] rows [0:4415];\ninitial begin\n'
    rom += ''.join(f" rows[{i}]=16'h{v:04x};\n" for i,v in enumerate(rows))
    rom += 'end\nalways @(posedge clk) data<=rows[address];\nendmodule\n'
    (out/'font_rom.v').write_text(rom, encoding='ascii')
    if update_rtl:
        rtl = ROOT/'user_source/hdl_source/scene/scene_text_overlay.v'
        original = rtl.read_text(encoding='utf-8').split(MARKER)[0]
        rtl.write_text(original+rom, encoding='utf-8')
    print(f'PASS PS1: {len(text)} bytes, {len(glyphs)} glyphs, {sum(map(len,scripts))} characters')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--update-rtl', action='store_true')
    args = parser.parse_args()
    generate(args.out, args.update_rtl)
