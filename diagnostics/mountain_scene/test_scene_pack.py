"""M2 semantic tests, scalar reference oracle and fresh-directory CLI regression."""
import importlib.util
from contextlib import contextmanager
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image
import yaml


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/make_scene_pack.py"
spec = importlib.util.spec_from_file_location("scene_pack", SCRIPT)
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)


@contextmanager
def evidence_directory():
    output = ROOT / "diagnostics/output"
    output.mkdir(exist_ok=True)
    # Retain every run, including failed cases; no recursive test cleanup.
    yield tempfile.mkdtemp(prefix="m2_test_", dir=output)


class ScenePackTests(unittest.TestCase):
    def test_raw_bmp_layout_and_roundtrip(self):
        # Odd width, distinct rows/channels, all sentinel and reserved values.
        rgb = np.arange(18, dtype=np.uint8).reshape(2, 3, 3)
        times = np.array([[0, 239, 250], [240, 254, 255]], dtype=np.uint8)
        with evidence_directory() as folder:
            path = Path(folder) / "odd.bmp"
            pack.write_bmp32(path, rgb, times)
            raw = path.read_bytes()
            self.assertEqual(len(raw), 78)
            self.assertEqual(struct.unpack_from("<IiiHHI", raw, 14), (40, 3, 2, 1, 32, 0))
            self.assertEqual(raw[54:58], bytes([11, 10, 9, 240]))
            self.assertEqual(raw[-4:], bytes([8, 7, 6, 250]))
            actual_rgb, actual_t = pack.read_bmp32(path)
            np.testing.assert_array_equal(actual_rgb, rgb)
            np.testing.assert_array_equal(actual_t, times)
            for offset, value in ((14, 108), (26, 2), (28, 24), (30, 3), (22, 0)):
                changed = bytearray(raw)
                changed[offset] = value
                path.write_bytes(changed)
                with self.assertRaises(ValueError):
                    pack.read_bmp32(path)
            path.write_bytes(raw[:-1])
            with self.assertRaises(ValueError):
                pack.read_bmp32(path)

    def test_grayscale_quantization_masks_and_alpha(self):
        with evidence_directory() as folder:
            folder = Path(folder)
            rgba = np.zeros((1, 256, 4), dtype=np.uint8)
            rgba[0, :, :3] = np.arange(256)[:, None]
            rgba[:, :, 3] = 255
            rgba[0, 2, 3] = 0
            Image.fromarray(rgba).save(folder / "gray.png")
            mask = np.full((1, 256), 255, dtype=np.uint8)
            mask[0, 3] = 0
            Image.fromarray(mask).save(folder / "mask.png")
            times = pack.gray_times({"path": "gray.png", "mask": "mask.png"}, folder, (256, 1))
            expected = [x*239//255 for x in range(256)]
            expected[2:4] = [255, 255]
            self.assertEqual(times[0].tolist(), expected)

    def test_polyline_accumulates_length_across_bend(self):
        times = pack.polyline_times({"points": [[1, 1], [5, 1], [5, 4]], "width": 1}, (8, 6))
        self.assertEqual([int(times[y, x]) for x, y in ((1, 1), (5, 1), (5, 2), (5, 4), (2, 2))],
                         [0, 136, 170, 239, 255])
        times = pack.polyline_times({"points": [[1, 1], [1, 1], [5, 1]], "width": 1,
                                    "start": 20, "end": 100}, (8, 6))
        self.assertEqual((int(times[1, 1]), int(times[1, 3]), int(times[1, 5])), (20, 60, 100))
        with self.assertRaises(ValueError):
            pack.polyline_times({"points": [[1, 1], [1, 1]]}, (8, 6))

    def test_chamfer_matches_closed_form_multiple_seeds(self):
        seeds = np.zeros((11, 13), dtype=bool)
        points = ((1, 2), (9, 7), (12, 0))
        for x, y in points:
            seeds[y, x] = True
        actual = pack.chamfer_distance(seeds)
        expected = [[min(3*max(abs(x-sx), abs(y-sy)) + min(abs(x-sx), abs(y-sy))
                         for sx, sy in points) for x in range(13)] for y in range(11)]
        np.testing.assert_array_equal(actual, expected)

    def test_seed_radius_and_seed_mask(self):
        with evidence_directory() as folder:
            folder = Path(folder)
            mask = np.zeros((7, 7), dtype=np.uint8)
            mask[3, 3] = 255
            Image.fromarray(mask).save(folder / "seeds.png")
            times = pack.seed_times({"seed_mask": "seeds.png", "max_distance": 2}, folder, (7, 7))
            self.assertEqual([int(times[y, x]) for x, y in ((3, 3), (4, 3), (4, 4), (5, 3), (6, 3))],
                             [0, 119, 159, 239, 255])
            with self.assertRaises(ValueError):
                pack.seed_times({"points": [], "max_distance": 2}, folder, (7, 7))

    def test_merge_earliest_and_safe_spot_priority(self):
        stage = {"sources": [{"type": "polyline", "points": [[0, 2], [6, 2]], "width": 1},
                             {"type": "polyline", "points": [[6, 2], [0, 2]], "width": 1}]}
        times = pack.make_times(stage, {"safe_spots": [{"center": [3, 2], "radius": 0}]}, Path('.'), (7, 5))
        self.assertEqual(times[2].tolist(), [0, 39, 79, 250, 79, 39, 0])
        self.assertEqual(int(times[0, 0]), 255)

    def test_reference_against_scalar_oracle_all_T_and_phases(self):
        # Explicit constants and scalar branches independently check vector arithmetic.
        hazards = ((0, 0, 0), (96, 48, 16), (0, 96, 224), (0, 192, 64))
        fronts = ((0, 0, 0), (255, 224, 0), (255, 255, 255), (0, 255, 0))
        times = np.arange(256, dtype=np.uint8).reshape(1, 256)
        rgb = np.array([[(v, (v*7+1)%256, (v*13+3)%256) for v in range(256)]], dtype=np.uint8)
        for stage in range(4):
            for now in (0, 5, 6, 120, 239):
                for fast, slow in ((0, 0), (0, 1), (1, 0), (1, 1)):
                    expected = []
                    for v, pixel in enumerate(rgb[0].tolist()):
                        value = pixel
                        if stage and v < 240 and v <= now:
                            front = now-v < 6
                            if front and fast:
                                value = fronts[stage]
                            else:
                                weight = 3 if front or stage != 2 else 1
                                value = tuple((c+weight*h)//(weight+1) for c, h in zip(pixel, hazards[stage]))
                        elif v == 250 and slow:
                            value = (0, 255, 0)
                        expected.append(value)
                    np.testing.assert_array_equal(pack.hazard_reference(rgb, times, stage, now, fast, slow),
                                                  np.array([expected], dtype=np.uint8))
        for kw in ({"enable": False}, {"thumbnail": True}):
            np.testing.assert_array_equal(pack.hazard_reference(rgb, times, 3, 239, True, True, **kw), rgb)

    def test_demo_cli_and_saved_assets(self):
        scene_path = ROOT / "tools/scenes/demo_village/scene.yaml"
        scene = yaml.safe_load(scene_path.read_text(encoding="utf-8"))
        with evidence_directory() as folder:
            out = Path(folder) / "fresh"
            result = subprocess.run([sys.executable, "-I", str(SCRIPT), str(scene_path), "--output", str(out)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(len(list(out.glob("PIC*.BMP"))), 4)
            self.assertEqual(len(list((out / "expected").glob("*.png"))), 24)
            for stage in scene["stages"]:
                i = stage["id"]
                rgb, times = pack.read_bmp32(out / f"PIC{i}.BMP")
                self.assertEqual(manifest["files"][i-1]["bytes"], 1228854)
                base = pack.image_array(scene_path.parent / scene["base"], "RGB", (640, 480))
                np.testing.assert_array_equal(rgb, base)
                self.assertEqual(int(times[132, 544]), 250)
                self.assertEqual(int(times[479, 639]), 255)
                self.assertFalse(np.isin(times, [240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 251, 252, 253, 254]).any())
            before = (out / "PIC1.BMP").read_bytes()
            result = subprocess.run([sys.executable, "-I", str(SCRIPT), str(scene_path), "--output", str(out)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("output already exists", result.stderr)
            self.assertEqual((out / "PIC1.BMP").read_bytes(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
