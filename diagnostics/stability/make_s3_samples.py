"""Generate local S3 comparison fixtures; does not read/write the TF card."""
from pathlib import Path
import struct
import zipfile
from make_s2_samples import picture


def unsupported_bmp(width, height, bpp, rgb):
    stride = ((width * bpp + 31) // 32) * 4
    data = bytearray(54)
    data[:2] = b"BM"
    struct.pack_into("<I", data, 2, 54 + stride * height)
    struct.pack_into("<I", data, 10, 54)
    struct.pack_into("<IiiHHII", data, 14, 40, width, height, 1, bpp, 0, stride * height)
    pixel = bytes(reversed(rgb)) + (b"\x00" if bpp == 32 else b"")
    row = pixel * width + bytes(stride - width * len(pixel))
    return data + row * height


def main():
    out = Path(__file__).resolve().parents[1] / "output" / "stability_s3_samples"
    out.mkdir(parents=True, exist_ok=True)
    files = {
        "01_skip_1600x1200_yellow.bmp": unsupported_bmp(1600, 1200, 24, (230, 210, 40)),
        "02_skip_32bit_magenta.bmp": unsupported_bmp(640, 480, 32, (220, 40, 220)),
        "03_good_red.bmp": picture(40, (220, 50, 40)),
        "04_good_green.bmp": picture(108, (40, 200, 65)),
        "05_good_blue.bmp": picture(124, (40, 80, 220)),
        "06_good_cyan.bmp": picture(40, (40, 200, 200)),
    }
    with zipfile.ZipFile(out / "board_samples.zip", "w", zipfile.ZIP_DEFLATED) as bundle:
        for name, data in files.items():
            (out / name).write_bytes(data)
            assert len(data) == struct.unpack_from("<I", data, 2)[0]
            bundle.write(out / name, name)
    print(f"PASS 2 trustworthy unsupported BMPs and 4 valid pictures: {out}")


if __name__ == "__main__":
    main()
