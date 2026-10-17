"""Render M6 original pages into a NEW directory, without generating test tones."""
import argparse
import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("renderer", HERE.parent / "geohazard_basics/make_inputs.py")
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--font", type=Path, default=Path("C:/Windows/Fonts/simhei.ttf"))
    args = parser.parse_args()
    report = renderer.generate(args.output, args.font, HERE / "content.yaml", test_tones=False)
    print(f"Rendered {len(report['pages'])} M6 pages; text bounds checked; no test tones")
