"""M5 binary format, legacy prefix, bounds and complete fresh-output reproduction."""
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from scene_text import encode_text, ESCAPES

DEMO = ROOT / 'tools/scenes/demo_village'


class SceneTextTests(unittest.TestCase):
    def setUp(self):
        self.cfg = yaml.safe_load((DEMO / 'scene.yaml').read_text(encoding='utf-8'))

    def test_format_and_case_prefix(self):
        font, text, meta = encode_text(self.cfg['text'], self.cfg['stages'])
        self.assertEqual(text[:4], b'TX\x01\x0a')
        source = (ROOT / 'user_source/hdl_source/osd/osd_font_cn_16x16.v').read_text(encoding='utf-8')
        glyphs = re.findall(r"8'h(8[0-9a-c]): bits = 256'([bh])([01a-f0-9]+);", source)
        self.assertEqual(len(glyphs), 13)
        for i, (_, radix, bits) in enumerate(glyphs):
            self.assertEqual(font[i*32:i*32+32], int(bits, 2 if radix == 'b' else 16).to_bytes(32, 'big'))
        offset = 44
        for i, segment in enumerate(meta['segments']):
            at, count, kind = struct.unpack_from('<HBB', text, 4+i*4)
            self.assertEqual((at, count, kind), (offset, len(segment), i % 2 if i < 8 else i-6))
            actual = text[at:at+count]
            self.assertEqual(actual, bytes(0xf0+ESCAPES.index(c) if c in ESCAPES else meta['slots'][c] for c in segment))
            offset += count
        self.assertEqual(offset, len(text))
        self.assertLessEqual(len(font), 4096)

    def test_bounds_and_escapes(self):
        # v0.25 S5: a segment may hold up to 255 characters (a stage's whole narration).
        spec = dict(titles=['0'*255]*4, subtitles=[ESCAPES]*4)
        font, text, _ = encode_text(spec, self.cfg['stages'])
        self.assertEqual(len(font), 416)
        self.assertIn(bytes(range(0xf0, 0x100)), text)
        for changed in [dict(titles=['0'*256]*4), dict(subtitles=['A']*4), dict(titles=['1']*3)]:
            with self.assertRaises(ValueError):
                encode_text(spec | changed, self.cfg['stages'])
        # 116 distinct new CJK glyphs exceed the 115 remaining slots.
        chars = ''.join(chr(0x4e00+i) for i in range(116))
        spec = dict(titles=[chars[i:i+29] for i in range(0,116,29)], subtitles=['']*4)
        with self.assertRaisesRegex(ValueError, '128'):
            encode_text(spec, self.cfg['stages'])

    def test_reproducible_and_existing_assets(self):
        folder = Path(tempfile.mkdtemp(prefix='m5_text_', dir=ROOT/'diagnostics/output'))
        out = folder / 'pack'
        cmd = [sys.executable, '-I', '-X', 'utf8', str(ROOT/'tools/make_scene_pack.py'), str(DEMO/'scene.yaml'), '--out', str(out)]
        result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(result.returncode, 0, result.stderr)
        baseline = folder / 'repeat'
        repeat = subprocess.run(cmd[:-1] + [str(baseline)], capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(repeat.returncode, 0, repeat.stderr)
        files = [p.relative_to(baseline) for p in baseline.rglob('*') if p.is_file()]
        self.assertEqual(set(files), {p.relative_to(out) for p in out.rglob('*') if p.is_file()})
        for name in files:
            self.assertEqual((out/name).read_bytes(), (baseline/name).read_bytes(), str(name))
        for i in range(1,5):
            for name in (f'PIC{i}.BMP', f'SND{i}.PCM'):
                self.assertEqual((out/name).read_bytes(), (ROOT/'releases/v0.17.0/m4-local.1/board_samples'/name).read_bytes(), name)
        fixed = ROOT / 'releases/v0.17.0/m5-local.1/board_samples'
        if fixed.is_dir():
            for name in ('FONT.BIN', 'TEXT.BIN', 'manifest.json'):
                self.assertEqual((out/name).read_bytes(), (fixed/name).read_bytes(), name)
        result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
        self.assertNotEqual(result.returncode, 0)
        for name in files:
            self.assertEqual((out/name).read_bytes(), (baseline/name).read_bytes(), str(name))
        print(f'PASS M5 fresh generation: {len(files)} files byte-equal; four PIC and four SND equal M4; existing output refused')


if __name__ == '__main__':
    unittest.main(verbosity=2)
