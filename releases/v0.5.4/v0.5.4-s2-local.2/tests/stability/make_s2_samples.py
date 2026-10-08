"""Create local BMP fixtures for S2 board checks; never accesses a TF card."""
from pathlib import Path
import struct
import zipfile


def picture(dib_size, color):
    width, height = 640, 480
    offset = 14 + dib_size
    header = bytearray(offset)
    header[:2] = b"BM"
    struct.pack_into("<I", header, 2, offset + width * height * 3)
    struct.pack_into("<I", header, 10, offset)
    struct.pack_into("<IiiHHII", header, 14, dib_size, width, height, 1, 24, 0, width * height * 3)
    if dib_size >= 108:
        struct.pack_into("<I", header, 70, 0x73524742)  # sRGB
    pixels = bytearray()
    for storage_y in range(height):
        y = height - 1 - storage_y
        for x in range(width):
            # White stripe at TOP and black stripe at LEFT reveal orientation.
            rgb = (255, 255, 255) if y < 40 else ((0, 0, 0) if x < 40 else color)
            pixels.extend(reversed(rgb))
    return header + pixels


def main():
    out = Path(__file__).resolve().parents[1] / "output" / "stability_s2_samples"
    out.mkdir(parents=True, exist_ok=True)
    samples = {
        "good_standard_red.bmp": picture(40, (220, 50, 40)),
        "good_v4_green.bmp": picture(108, (40, 200, 65)),
        "good_v5_blue.bmp": picture(124, (40, 80, 220)),
    }
    wrong_planes = picture(40, (230, 210, 40))
    struct.pack_into("<H", wrong_planes, 26, 2)
    samples["bad_planes_yellow.bmp"] = wrong_planes
    wrong_offset = picture(108, (220, 40, 220))
    struct.pack_into("<I", wrong_offset, 10, 54)
    samples["bad_offset_magenta.bmp"] = wrong_offset
    manifest = (
        "S2 board samples: 640x480, bottom-up, 24-bit.\n"
        "Copy all five to a clean contiguous-file test card: only RED, GREEN, BLUE should display.\n"
        "White stripe must be at TOP, black stripe at LEFT.\n"
        "Yellow has planes=2; magenta overlaps its V4 DIB with pixel_offset=54. Both must be rejected.\n"
        "Invalid-only test uses just the two bad files. Raw-sector scan can still discover old deleted BMPs;\n"
        "use a card without previous valid BMP remnants. This tool only creates local files.\n"
    )
    for name, data in samples.items():
        (out / name).write_bytes(data)
        file_size = struct.unpack_from("<I", data, 2)[0]
        assert len(data) == file_size
    (out / "README.txt").write_text(manifest, encoding="utf-8")
    with zipfile.ZipFile(out / "board_samples.zip", "w", zipfile.ZIP_DEFLATED) as bundle:
        for name in samples:
            bundle.write(out / name, name)
        bundle.write(out / "README.txt", "README.txt")
    print(f"PASS generated 3 valid and 2 rejected BMP fixtures: {out}")


if __name__ == "__main__":
    main()
