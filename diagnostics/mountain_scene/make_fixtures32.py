"""Use the existing FAT32 layouts/failures with 32bpp pixel payloads."""
from pathlib import Path
import runpy
import struct

namespace = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'fat32/generate_core_fixtures.py'))


def bmp32(seed):
    # Width 3: both old padded 24bpp rows and 32bpp rows are exactly 12 bytes.
    data = bytearray(54 + 12 * 91)
    data[:2] = b'BM'
    for off, value in ((2, len(data)), (10, 54), (14, 40), (18, 3), (22, 91)):
        struct.pack_into('<I', data, off, value)
    struct.pack_into('<HH', data, 26, 1, 32)
    for row in range(91):
        for col in range(3):
            at = 54 + row * 12 + col * 4
            data[at:at + 4] = bytes(((seed + row) & 255, col + 17,
                                    (row * 3 + seed) & 255, (row * 19 + col * 13 + seed) & 255))
    return data


namespace['generate'].__globals__['bmp'] = bmp32
namespace['main']()
