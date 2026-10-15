"""M6 two-card reproduction, independent raw bytes and alarm checks."""
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
import numpy as np
from PIL import Image
import yaml

ROOT = Path(__file__).resolve().parents[2]
SCENES = ROOT / 'tools/scenes'


class Cards(unittest.TestCase):
    def test_two_distinct_cards_and_text(self):
        for village, spot in [('m6_demo', (544, 132)), ('flood_village', (126, 246))]:
            folder = SCENES / village / 'generated'
            cfg = yaml.safe_load((SCENES / village / 'scene.yaml').read_text(encoding='utf-8'))
            text = (folder / 'TEXT.BIN').read_bytes()
            self.assertEqual(text[:4], b'TX\1\12')
            at, length, kind = struct.unpack_from('<HBB', text, 36)
            self.assertEqual((length, kind), (7, 2))
            self.assertEqual(text[at+length-1], 255)  # final ! escape
            self.assertEqual(cfg['text']['warning'], '\u7acb\u5373\u64a4\u5f80\u9ad8\u5730!')
            for stage in range(1, 5):
                raw = (folder / f'PIC{stage}.BMP').read_bytes()
                self.assertEqual(len(raw), 1228854)
                self.assertEqual(struct.unpack_from('<IiiHHI', raw, 14), (40, 640, 480, 1, 32, 0))
                x, y = spot
                self.assertEqual(raw[54 + ((479-y)*640+x)*4+3], 250)
        a, b = [SCENES / name / 'generated' for name in ('m6_demo', 'flood_village')]
        for name in ('PIC1.BMP', 'PIC4.BMP', 'FONT.BIN', 'TEXT.BIN'):
            self.assertNotEqual((a / name).read_bytes(), (b / name).read_bytes())

    def test_alarm_samples_and_frequency(self):
        raw = (SCENES / 'flood_village/generated/SND4.PCM').read_bytes()
        signal = np.frombuffer(raw, dtype='<i2')
        self.assertEqual(len(signal), 384000)
        self.assertEqual((int(signal[0]), int(signal[-1])), (0, 0))
        self.assertLessEqual(int(np.max(np.abs(signal))), 9000)
        self.assertGreater(np.count_nonzero(signal), 380000)
        # Positive crossings over each 100ms window give an independent
        # estimate of the audible siren sweep, without reusing its phase code.
        frequencies = []
        for i in range(4800, len(signal)-4800, 4800):
            chunk = signal[i:i+4800]
            frequencies.append(np.count_nonzero((chunk[:-1] <= 0) & (chunk[1:] > 0))*10)
        self.assertLess(min(frequencies), 640)
        self.assertGreater(max(frequencies), 960)
        self.assertGreater(min(frequencies), 570)
        self.assertLess(max(frequencies), 1030)
        for i in range(1, 5):
            with wave.open(str(SCENES / f'classroom_audio/stage{i}.wav')) as wav:
                self.assertEqual((wav.getframerate(), wav.getnchannels(), wav.getsampwidth()), (48000, 1, 2))
                self.assertEqual(wav.readframes(wav.getnframes()), (SCENES / f'm6_demo/generated/SND{i}.PCM').read_bytes())

    def test_reproduce_inputs(self):
        out = Path(tempfile.mkdtemp(prefix='m6_inputs_', dir=ROOT / 'diagnostics/output'))
        for script, folder, names in [
            (SCENES / 'flood_village/make_inputs.py', SCENES / 'flood_village', ('village.png', 'rainfall.png', 'rainfall_mask.png', 'flood_mask.png')),
            (SCENES / 'make_classroom_audio.py', SCENES / 'classroom_audio', tuple(f'stage{i}.wav' for i in range(1, 5)))]:
            target = out / script.stem
            command = [sys.executable, '-I', str(script), '--output', str(target)]
            subprocess.run(command, check=True, capture_output=True)
            for name in names:
                self.assertEqual((target/name).read_bytes(), (folder/name).read_bytes(), name)
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    def test_reproduce_both_packs(self):
        out = Path(tempfile.mkdtemp(prefix='m6_packs_', dir=ROOT / 'diagnostics/output'))
        for village in ('m6_demo', 'flood_village'):
            target = out / village
            command = [sys.executable, '-I', '-X', 'utf8', str(ROOT/'tools/make_scene_pack.py'),
                       str(SCENES/village/'scene.yaml'), '--output', str(target)]
            subprocess.run(command, check=True, capture_output=True)
            source_folder = SCENES/village/'generated'
            files = [f for f in source_folder.rglob('*') if f.is_file()]
            self.assertEqual(len(files), 44)
            self.assertEqual({f.relative_to(source_folder) for f in files}, {f.relative_to(target) for f in target.rglob('*') if f.is_file()})
            for source in files:
                self.assertEqual(source.read_bytes(), (target/source.relative_to(source_folder)).read_bytes(), source.name)
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
