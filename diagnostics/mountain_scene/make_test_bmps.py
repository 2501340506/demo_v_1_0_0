"""M1 diagnostic card only: BI_RGB BGRA BMPs and scaled RGB reference PNGs.

Usage: py -I diagnostics/mountain_scene/make_test_bmps.py <fresh-output-dir>
No scene definitions or hazard model (those belong to M2).
"""
from pathlib import Path
import struct
import sys
import zlib


def pixel(x, y, width, height):
    # Red horizontal and green vertical ramps; blue quadrants expose flips.
    r, g = x * 255 // max(1, width - 1), y * 255 // max(1, height - 1)
    b = (32, 96, 160, 224)[(y >= height // 2) * 2 + (x >= width // 2)]
    if x < 8 or y < 8 or x >= width - 8 or y >= height - 8:
        r, g, b = 255, 255, 255
    return r, g, b, (x * 13 + y * 19) & 255


def png(path, width, height, rgb):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    rows = b''.join(b'\0' + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def generate(out):
    out.mkdir(parents=True, exist_ok=False)
    for index, (width, height) in enumerate(((640, 480), (160, 120), (801, 601), (317, 479)), 1):
        size = 54 + width * height * 4
        header = struct.pack('<2sIHHI', b'BM', size, 0, 0, 54)
        header += struct.pack('<IiiHHIIiiII', 40, width, height, 1, 32, 0, width * height * 4, 0, 0, 0, 0)
        payload = bytearray()
        for y in reversed(range(height)):
            for x in range(width):
                r, g, b, t = pixel(x, y, width, height)
                payload.extend((b, g, r, t))
        path = out / f'PIC{index}.BMP'
        path.write_bytes(header + payload)
        # Read the saved file independently, including all coordinates and T.
        saved = path.read_bytes()
        assert struct.unpack_from('<IiiHHI', saved, 14) == (40, width, height, 1, 32, 0)
        assert len(saved) == struct.unpack_from('<I', saved, 2)[0] == size
        for y in range(height):
            for x in range(width):
                b, g, r, t = struct.unpack_from('BBBB', saved, 54 + ((height - 1 - y) * width + x) * 4)
                assert (r, g, b, t) == pixel(x, y, width, height)
        if width * 480 >= height * 640:
            dw, dh = 640, height * 640 // width
        else:
            dw, dh = width * 480 // height, 480
        left, top = (640 - dw) // 2, (480 - dh) // 2
        rgb = bytearray(640 * 480 * 3)
        for y in range(top, top + dh):
            for x in range(left, left + dw):
                sx, sy = (x - left) * width // dw, (y - top) * height // dh
                at = (y * 640 + x) * 3
                rgb[at:at + 3] = bytes(pixel(sx, sy, width, height)[:3])
        png(out / f'PIC{index}_expected.png', 640, 480, rgb)
        print(f'PASS sample PIC{index}.BMP {width}x{height} {size} bytes; all RGB/T bytes read back')


if __name__ == '__main__':
    generate(Path(sys.argv[1]))
