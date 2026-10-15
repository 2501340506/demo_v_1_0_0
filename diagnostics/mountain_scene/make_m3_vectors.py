"""Export M2 saved BMP/PNG bytes for RTL, without recomputing expected pixels."""
from pathlib import Path
import argparse
import struct
from PIL import Image

root = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('output', type=Path)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
source = root / 'tools/scenes/demo_village/generated'
for i in range(1, 5):
    raw = (source / f'PIC{i}.BMP').read_bytes()
    assert struct.unpack_from('<IiiHHI', raw, 14) == (40, 640, 480, 1, 32, 0)
    rgba = bytearray()
    for y in range(480):
        row = raw[54+(479-y)*2560:54+(480-y)*2560]
        for x in range(640):
            b,g,r,t = row[x*4:x*4+4]
            rgba.extend((r,g,b,t))
    (a.output / f'PIC{i}.rgba').write_bytes(rgba)
    for t in (0, 120, 239):
        for phase in ('bright', 'dark'):
            name = f'PIC{i}_t{t:03}_{phase}'
            with Image.open(source / 'expected' / (name+'.png')) as image:
                assert image.mode == 'RGB' and image.size == (640,480)
                (a.output / (name+'.rgb')).write_bytes(image.tobytes())
print('PASS M3 vectors: 4 saved BMP payloads and 24 saved expected PNGs exported')
