"""PC-only format/negative/reproduction tests. Keeps fixtures; never deletes them.

py -I -X utf8 diagnostics/publicity_mode/test_publicity_pack.py --output NEW
"""
from __future__ import annotations

import argparse
import copy
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import wave

from PIL import Image
import yaml

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "tools/publicity/geohazard_basics"


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


PACK = module("publicity_pack", ROOT / "tools/make_publicity_pack.py")
INPUTS = module("publicity_inputs", CONTENT / "make_inputs.py")


def tree(path):
    return {p.relative_to(path).as_posix(): p.read_bytes() for p in path.rglob("*") if p.is_file()}


class PublicityTests(unittest.TestCase):
    evidence = {}

    def setUp(self):
        self.folder = Path(tempfile.mkdtemp(prefix=self._testMethodName + "_", dir=RUN))
        self.spec = yaml.safe_load((CONTENT / "pack.yaml").read_text(encoding="utf-8"))
        for page in self.spec["pages"]:
            for key in ("image", "audio", "script"):
                page[key] = str(CONTENT / page[key])
            page["source_refs"] = [str(CONTENT / p) for p in page["source_refs"]]

    def config(self, spec=None):
        path = self.folder / f"config{len(list(self.folder.glob('config*.yaml')))}.yaml"
        path.write_text(yaml.safe_dump(spec or self.spec, allow_unicode=True), encoding="utf-8")
        return path

    def reject(self, spec=None):
        output = self.folder / f"rejected{len(list(self.folder.glob('config*.yaml')))}"
        with self.assertRaises((ValueError, OSError, KeyError, wave.Error, EOFError, yaml.YAMLError)):
            PACK.compile_pack(self.config(spec), output)
        self.assertFalse(output.exists(), "invalid input must fail before output creation")

    def wav(self, name, channels=1, width=2, rate=48000, payload=b"\x01\x02"*200):
        path = self.folder / name
        with wave.open(str(path), "wb") as wav:
            wav.setparams((channels, width, rate, 0, "NONE", "not compressed"))
            wav.writeframes(payload)
        return path

    def test_01_independent_bmp_and_pcm_readback(self):
        generated = CONTENT / "generated"
        manifest = json.loads((generated / "manifest.json").read_text(encoding="utf-8"))
        all_pcm = []
        for slot in range(1, 5):
            data = (generated / f"EDU{slot}.BMP").read_bytes()
            self.assertEqual(len(data), 921654)
            self.assertEqual(struct.unpack_from("<2sIHHI", data), (b"BM", 921654, 0, 0, 54))
            self.assertEqual(struct.unpack_from("<IiiHHII", data, 14), (40, 640, 480, 1, 24, 0, 921600))
            # Independent reference: explicit row reversal and channel strides,
            # not PACK.read_bmp24 or PIL's raw BGR encoder/decoder.
            expected = bytearray()
            with Image.open(CONTENT / f"inputs/page{slot}.png") as source:
                rgb = source.tobytes()
                for y in range(479, -1, -1):
                    row = rgb[y*1920:(y+1)*1920]
                    bgr = bytearray(1920)
                    bgr[0::3], bgr[1::3], bgr[2::3] = row[2::3], row[1::3], row[0::3]
                    expected.extend(bgr)
                self.assertEqual(data[54:], expected)
                with Image.open(generated / f"EDU{slot}.BMP") as decoded:
                    self.assertEqual(decoded.size, (640, 480))
                    self.assertEqual(decoded.tobytes(), rgb)
                with Image.open(generated / f"previews/EDU{slot}.png") as preview:
                    self.assertEqual(preview.tobytes(), rgb)
            pcm = (generated / f"VOI{slot}.PCM").read_bytes()
            with wave.open(str(CONTENT / f"inputs/test_tone{slot}.wav"), "rb") as wav:
                self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, 48000))
                self.assertEqual(pcm, wav.readframes(wav.getnframes()))
            seconds = (2, 6, 8, 10)[slot-1]
            self.assertEqual(len(pcm), seconds*96000)
            self.assertNotEqual(pcm[:4], b"RIFF")
            record = manifest["pages"][slot-1]
            self.assertEqual((record["pcm_samples"], record["duration_seconds"]), (seconds*48000, seconds))
            self.assertEqual(record["audio_status"], "test_tone")
            self.assertFalse(record["audio_matches_script"])
            all_pcm.append(pcm)
        self.assertEqual(len(set(all_pcm)), 4)
        self.assertFalse(manifest["formal_narration"])
        self.assertEqual(manifest["content_review"], "pending_human_review")
        self.evidence["readback"] = {"bmp_pixels": 1228800, "bmp_bytes": 3686616,
                                     "pcm_bytes": 2496000, "pcm_samples": 1248000,
                                     "seconds": [2, 6, 8, 10]}

    def test_02_reproduce_all_output_bytes(self):
        first = self.folder / "parentA/pack"
        second = self.folder / "parentB/different_name"
        PACK.compile_pack(CONTENT / "pack.yaml", first)
        PACK.compile_pack(CONTENT / "pack.yaml", second)
        expected = tree(CONTENT / "generated")
        self.assertEqual(tree(first), expected)
        self.assertEqual(tree(second), expected)
        self.assertEqual(len(expected), 14)
        self.evidence["pack_reproduction"] = {"files_per_tree": len(expected),
                                               "bytes_per_tree": sum(map(len, expected.values())),
                                               "compared_to_frozen_trees": 2}

    def test_03_reproduce_input_bytes_and_layout(self):
        output = self.folder / "drawn"
        report = INPUTS.generate(output, Path("C:/Windows/Fonts/simhei.ttf"))
        self.assertEqual(tree(output), tree(CONTENT / "inputs"))
        count = 0
        for page in report["pages"]:
            for item in page["text_bounds"]:
                x1, y1, x2, y2 = item["box"]
                self.assertTrue(0 <= x1 < x2 <= 640 and 60 <= y1 < y2 <= 480)
                self.assertFalse(max(x1, 420) < min(x2, 624) and max(y1, 210) < min(y2, 412))
                count += 1
        with self.assertRaises(ValueError):
            INPUTS.generate(output, Path("C:/Windows/Fonts/simhei.ttf"))
        self.evidence["input_reproduction"] = {"files": 9, "text_boxes_checked": count,
                                                "pillow_version": report["pillow_version"],
                                                "font_file": report["font_file"], "font_bytes": report["font_bytes"]}

    def test_04_order_count_and_duplicate_ids(self):
        for ids in ([1, 2, 3], [1, 2, 3, 4, 4], [1, 2, 2, 4], [2, 1, 3, 4], [True, 2, 3, 4]):
            with self.subTest(ids=ids):
                spec = copy.deepcopy(self.spec)
                spec["pages"] = [dict(self.spec["pages"][0], id=i) for i in ids]
                self.reject(spec)

    def test_05_dimensions_alpha_and_palette_rejected(self):
        for i, (mode, size) in enumerate((("RGB", (639, 480)), ("RGBA", (640, 480)), ("P", (640, 480)))):
            path = self.folder / f"bad{i}.png"
            Image.new(mode, size).save(path)
            self.spec["pages"][0]["image"] = str(path)
            self.reject()

    def test_06_missing_resources(self):
        for key in ("image", "audio", "script"):
            with self.subTest(key=key):
                spec = copy.deepcopy(self.spec)
                spec["pages"][0][key] = str(self.folder / "missing")
                self.reject(spec)
        self.spec["pages"][0]["source_refs"] = [str(self.folder / "missing_source.md")]
        self.reject()

    def test_07_wav_format_rejection(self):
        for i, options in enumerate((dict(rate=44100), dict(channels=2), dict(width=1), dict(payload=b""))):
            self.spec["pages"][0]["audio"] = str(self.wav(f"bad{i}.wav", **options))
            self.reject()
        path = self.folder / "not_wav.wav"
        path.write_bytes(b"raw pcm")
        self.spec["pages"][0]["audio"] = str(path)
        self.reject()

    def test_08_truncated_and_odd_wav_rejected(self):
        good = self.wav("good.wav").read_bytes()
        for i, data in enumerate((good[:-2], good[:-1])):
            path = self.folder / f"truncated{i}.wav"
            path.write_bytes(data)
            self.spec["pages"][0]["audio"] = str(path)
            self.reject()
        # RIFF declares an odd data size: not valid 16-bit whole samples.
        odd = bytearray(good[:-1])
        struct.pack_into("<I", odd, 4, len(odd)-8)
        struct.pack_into("<I", odd, 40, len(odd)-44)
        path = self.folder / "odd.wav"
        path.write_bytes(odd)
        self.spec["pages"][0]["audio"] = str(path)
        self.reject()

    def test_09_explicit_missing_audio(self):
        self.spec["pages"][1].update(audio=None, audio_status="missing")
        output = self.folder / "no_voice"
        result = PACK.compile_pack(self.config(), output)
        page = result["pages"][1]
        self.assertEqual((page["pcm"], page["pcm_samples"], page["audio_status"]), (None, 0, "missing"))
        self.assertFalse((output / "VOI2.PCM").exists())
        self.assertTrue((output / "VOI3.PCM").exists())

    def test_10_short_file_under_sector(self):
        self.spec["pages"][0]["audio"] = str(self.wav("short.wav", payload=b"\x01\x00"*3))
        output = self.folder / "short"
        result = PACK.compile_pack(self.config(), output)
        self.assertEqual((output / "VOI1.PCM").read_bytes(), b"\x01\x00"*3)
        self.assertEqual(result["pages"][0]["pcm_samples"], 3)

    def test_11_refuse_overwrite_empty_dir_file_and_populated(self):
        for name, content in (("empty", None), ("file", b"user data"), ("populated", None)):
            output = self.folder / name
            if content is None:
                output.mkdir()
                if name == "populated":
                    (output / "sentinel").write_bytes(b"preserve me")
                before = tree(output)
            else:
                output.write_bytes(content)
                before = output.read_bytes()
            with self.assertRaises(ValueError):
                PACK.compile_pack(CONTENT / "pack.yaml", output)
            self.assertEqual(tree(output) if content is None else output.read_bytes(), before)

    def test_12_status_and_required_fields(self):
        variants = []
        for key in ("title", "script", "image", "audio", "source_refs"):
            spec = copy.deepcopy(self.spec)
            del spec["pages"][0][key]
            variants.append(spec)
        for status, audio in (("formal", self.spec["pages"][0]["audio"]), ("test_tone", None), ("missing", "")):
            spec = copy.deepcopy(self.spec)
            spec["pages"][0].update(audio=audio, audio_status=status)
            variants.append(spec)
        for spec in variants:
            self.reject(spec)

    def test_13_bad_bmp_readback(self):
        good = (CONTENT / "generated/EDU1.BMP").read_bytes()
        for data in (good[:-1], b"ZZ"+good[2:], good[:28]+b"\x20\x00"+good[30:]):
            with self.assertRaises(ValueError):
                PACK.read_bmp24(data)

    def test_14_empty_script_and_source_rejected(self):
        for key in ("script", "source_refs"):
            path = self.folder / f"empty_{key}.txt"
            path.write_text("\n  ", encoding="utf-8")
            spec = copy.deepcopy(self.spec)
            spec["pages"][0][key] = [str(path)] if key == "source_refs" else str(path)
            self.reject(spec)

    def test_15_manifest_and_overview(self):
        output = CONTENT / "generated"
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["files"]), 13)
        for entry in manifest["files"]:
            self.assertEqual((output / entry["path"]).stat().st_size, entry["bytes"])
        for page in manifest["pages"]:
            self.assertEqual(page["script"], (CONTENT / page["script_input"]).read_text(encoding="utf-8").strip())
            self.assertTrue(page["source_refs"])
        with Image.open(output / "previews/overview.png") as overview:
            self.assertEqual(overview.size, (1280, 960))
            for i in range(4):
                x, y = i % 2 * 640, i // 2 * 480
                with Image.open(CONTENT / f"inputs/page{i+1}.png") as page:
                    self.assertEqual(overview.crop((x, y, x+640, y+480)).tobytes(), page.tobytes())

    def test_16_existing_audio_tool_matches_and_cli(self):
        common = ["py", "-I", "-X", "utf8"]
        for slot in range(1, 5):
            output = self.folder / f"existing{slot}.pcm"
            process = subprocess.run(common + [str(ROOT / "tools/make_audio_corpus.py"),
                                     str(CONTENT / f"inputs/test_tone{slot}.wav"), str(output)],
                                     capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual(output.read_bytes(), (CONTENT / f"generated/VOI{slot}.PCM").read_bytes())
        output = self.folder / "cli"
        command = common + [str(ROOT / "tools/make_publicity_pack.py"), str(CONTENT / "pack.yaml"), "--output", str(output)]
        process = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(tree(output), tree(CONTENT / "generated"))
        before = tree(output)
        again = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(again.returncode, 2)
        self.assertEqual(tree(output), before)


def main():
    global RUN
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("output must not exist")
    RUN = args.output.resolve()
    RUN.mkdir(parents=True, exist_ok=False)
    with (RUN / "test.log").open("w", encoding="utf-8") as log:
        result = unittest.TextTestRunner(stream=log, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PublicityTests))
    report = {"tests": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "success": result.wasSuccessful(), "scope": "PC-only; no RTL simulation or TD build",
              "evidence": PublicityTests.evidence}
    (RUN / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print((RUN / "test.log").read_text(encoding="utf-8"))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
