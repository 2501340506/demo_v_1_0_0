"""Read a card and produce an additive thumbnail ZIP plus a preserved full ZIP."""
import argparse
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from make_menu_thumbnails import SCENES, thumbnail


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--card', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    originals = {}
    for directory in ('情景模式', '宣讲模式'):
        for source in sorted((args.card / directory).rglob('*')):
            if source.is_file() and source.name.upper() != 'THUMB.BMP':
                originals[source.relative_to(args.card).as_posix()] = source.read_bytes()
    if not originals:
        raise ValueError('No application resources found')
    additions = {}
    for scene in SCENES:
        rel = f'情景模式/{scene}/THUMB.BMP'
        output = thumbnail(args.card / '情景模式' / scene / 'PIC1.BMP', args.out / 'card' / rel)
        repeat = thumbnail(args.card / '情景模式' / scene / 'PIC1.BMP', args.out / 'repeat' / rel)
        assert output.read_bytes() == repeat.read_bytes(), rel
        additions[rel] = output.read_bytes()
    for name, content in (('thumbnail_additions.zip', additions),
                          ('full_sd_resources.zip', originals | additions)):
        with zipfile.ZipFile(args.out / name, 'w', zipfile.ZIP_DEFLATED) as archive:
            for rel, data in content.items():
                archive.writestr(rel, data)
        with zipfile.ZipFile(args.out / name) as archive:
            assert set(archive.namelist()) == set(content)
            for rel, data in content.items():
                assert archive.read(rel) == data, (name, rel)
    for rel, data in originals.items():
        assert (args.card / rel).read_bytes() == data, 'Card changed: ' + rel
    manifest = dict(original_files=[dict(file=r, bytes=len(b)) for r, b in originals.items()],
                    thumbnail_files=[dict(file=r, bytes=len(b)) for r, b in additions.items()],
                    verification='ZIP readback and original card files compared byte for byte; no card writes',
                    format='256x192 24-bit BI_RGB BMP',
                    original_bytes=sum(map(len, originals.values())),
                    thumbnail_bytes=sum(map(len, additions.values())))
    (args.out / 'assets_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'PASS preserved {len(originals)} originals/{manifest["original_bytes"]} bytes; '
          f'added {len(additions)} thumbnails/{manifest["thumbnail_bytes"]} bytes; ZIPs read back byte for byte')


if __name__ == '__main__':
    main()
