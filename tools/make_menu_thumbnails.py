"""Generate THUMB.BMP beside staged PIC1 resources; never changes PIC/PCM/BIN.

py -I -X utf8 tools/make_menu_thumbnails.py --source G:/情景模式 --out diagnostics/output/menu_card
The output contains only <scene>/THUMB.BMP, suitable for additive card copying.
"""
from pathlib import Path
import argparse
import struct
import numpy as np
from PIL import Image

SCENES = ('landslide_village', 'debris_village', 'flood_village', 'quake_village')


def thumbnail(source, destination):
    """Match full-frame integer letterboxing followed by the old menu samples."""
    source, destination = Path(source), Path(destination)
    with Image.open(source) as image:
        w, h = image.size
        if not (1 <= w <= 1920 and 1 <= h <= 1920 and
                ((w <= 1920 and h <= 1080) or (w <= 1080 and h <= 1920))):
            raise ValueError(f'Unsupported image size: {source}: {w}x{h}')
        rgb = np.asarray(image.convert('RGB'))
    if w * 480 >= h * 640:
        dw, dh = 640, max(1, h * 640 // w)
    else:
        dw, dh = max(1, w * 480 // h), 480
    left, top = (640 - dw) // 2, (480 - dh) // 2
    # Compute only the 49152 destination samples; no 640x480 staging image.
    xs, ys = np.arange(256) * 5 // 2, np.arange(192) * 5 // 2
    inside = ((ys[:, None] >= top) & (ys[:, None] < top + dh) &
              (xs[None, :] >= left) & (xs[None, :] < left + dw))
    sx = np.clip((xs - left) * w // dw, 0, w - 1)
    sy = np.clip((ys - top) * h // dh, 0, h - 1)
    result = np.where(inside[..., None], rgb[sy[:, None], sx[None, :]], 0).astype('uint8')
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(result, 'RGB').save(destination, format='BMP')
    data = destination.read_bytes()
    if len(data) != 147510 or struct.unpack_from('<iiHHI', data, 18) != (256, 192, 1, 24, 0):
        raise ValueError(f'Unexpected generated BMP format: {destination}')
    with Image.open(destination) as actual:
        if not np.array_equal(np.asarray(actual), result):
            raise ValueError(f'BMP round trip failed: {destination}')
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    for scene in SCENES:
        path = thumbnail(args.source / scene / 'PIC1.BMP', args.out / scene / 'THUMB.BMP')
        print(f'{path}: {path.stat().st_size} bytes')


if __name__ == '__main__':
    main()
