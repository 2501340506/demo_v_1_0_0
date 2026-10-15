"""M4 corpus byte correctness, compatibility and input/output preservation."""
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]
CONVERTER = ROOT / 'tools/make_audio_corpus.py'
PACK = ROOT / 'tools/make_scene_pack.py'
DEMO = ROOT / 'tools/scenes/demo_village'


def invoke(script, *args):
    return subprocess.run([sys.executable, '-I', str(script), *map(str, args)],
                          capture_output=True, text=True)


class SceneAudioTests(unittest.TestCase):
    def setUp(self):
        self.folder = Path(tempfile.mkdtemp(prefix='m4_audio_', dir=ROOT / 'diagnostics/output'))

    def test_exact_signed_pcm_and_preservation(self):
        source, destination = self.folder / 'signed.wav', self.folder / 'out.PCM'
        payload = struct.pack('<7h', -32768, -12345, -1, 0, 1, 23456, 32767)
        with wave.open(str(source), 'wb') as wav:
            wav.setparams((1, 2, 48000, 7, 'NONE', 'not compressed'))
            wav.writeframes(payload)
        original = source.read_bytes()
        result = invoke(CONVERTER, source, destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), payload)
        self.assertNotEqual(invoke(CONVERTER, source, destination).returncode, 0)
        self.assertEqual(destination.read_bytes(), payload)
        self.assertNotEqual(invoke(CONVERTER, source, source, '--force').returncode, 0)
        self.assertEqual(source.read_bytes(), original)
        destination.write_bytes(b'old')
        self.assertEqual(invoke(CONVERTER, source, destination, '--force').returncode, 0)
        self.assertEqual(destination.read_bytes(), payload)

    def test_truncated_even_length_wav_rejected(self):
        source, destination = self.folder / 'short.wav', self.folder / 'out.PCM'
        with wave.open(str(source), 'wb') as wav:
            wav.setparams((1, 2, 48000, 20, 'NONE', 'not compressed'))
            wav.writeframes(bytes(40))
        source.write_bytes(source.read_bytes()[:-4])
        result = invoke(CONVERTER, source, destination)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('truncated WAV', result.stderr)
        self.assertFalse(destination.exists())

    def test_demo_reproduction_audio_and_image_compatibility(self):
        destination = self.folder / 'pack'
        result = invoke(PACK, DEMO / 'scene.yaml', '--output', destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        for path in (DEMO / 'generated').rglob('*'):
            if path.is_file() and path.name != 'manifest.json':
                self.assertEqual(path.read_bytes(), (destination / path.relative_to(DEMO / 'generated')).read_bytes())
        manifest = json.loads((destination / 'manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest['format'], 'M5-scene-v1')
        self.assertEqual(len(manifest['audio']), 4)
        for index, record in enumerate(manifest['audio'], 1):
            with wave.open(str(DEMO / f'placeholder{index}.wav'), 'rb') as wav:
                self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, 48000))
                payload = wav.readframes(wav.getnframes())
            actual = (destination / f'SND{index}.PCM').read_bytes()
            self.assertEqual(actual, payload)
            self.assertEqual(actual, (DEMO / 'generated_m4' / f'SND{index}.PCM').read_bytes())
            self.assertEqual((record['bytes'], record['samples'], record['seconds']), (768000, 384000, 8.0))
            self.assertEqual(actual[:2], bytes(2))
            self.assertEqual(actual[-2:], bytes(2))
        self.assertNotEqual(invoke(PACK, DEMO / 'scene.yaml', '--output', destination).returncode, 0)

    def test_image_only_and_bad_audio_inputs(self):
        import yaml
        scene = yaml.safe_load((DEMO / 'scene.yaml').read_text(encoding='utf-8'))
        scene['base'] = str(DEMO / scene['base'])
        # All remaining source paths must still refer to the preserved demo.
        for stage in scene['stages']:
            for item in stage.get('sources', []):
                for key in ('path', 'mask', 'seed_mask'):
                    if key in item:
                        item[key] = str(DEMO / item[key])
        scene.pop('audio')
        source = self.folder / 'scene.yaml'
        source.write_text(yaml.safe_dump(scene), encoding='utf-8')
        result = invoke(PACK, source, '--output', self.folder / 'images')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(list((self.folder / 'images').glob('SND*')))
        for audio in (['one.wav'], ['missing.wav'] * 4):
            scene['audio'] = audio
            source.write_text(yaml.safe_dump(scene), encoding='utf-8')
            result = invoke(PACK, source, '--output', self.folder / 'invalid')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((self.folder / 'invalid').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
