"""Add missing S2 FONT/TEXT/SND assets; never overwrite existing card files."""
import argparse
import json
from pathlib import Path
import struct
import sys
import wave
import os

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from scene_text import encode_text, ESCAPES

CONFIG = Path(__file__).with_name('card_resources.json')
NAMES = ['FONT.BIN', 'TEXT.BIN'] + [f'SND{i}.PCM' for i in range(1, 5)]


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def validate_text(font, text, meta):
    assert 416 <= len(font) <= 4096 and len(font) % 32 == 0
    assert text[:4] == b'TX\x01\x0a' and len(text) <= 4096
    slots = {v: k for k, v in meta['slots'].items()}
    cursor = 44
    for i, wanted in enumerate(meta['segments']):
        at, count, kind = struct.unpack_from('<HBB', text, 4 + 4*i)
        assert (at, count, kind) == (cursor, len(wanted), i % 2 if i < 8 else i-6)
        decoded = ''.join(slots[c] if c < 128 else ESCAPES[c-240] for c in text[at:at+count])
        assert decoded == wanted
        assert all(any(font[c*32:(c+1)*32]) for c in text[at:at+count] if c < 128)
        cursor += count
    assert cursor == len(text) and meta['segments'][8] == '立即撤离'


def prepare(card, out):
    assert card.is_dir(), card
    assert not out.exists(), 'Choose a fresh output directory'
    cfg = json.loads(CONFIG.read_text(encoding='utf-8'))
    # All validation and data assembly precede any output/card mutation.
    bundles = {}
    for folder, spec in cfg.items():
        source = card / folder
        assert source.is_dir(), source
        assert not any((source / n).exists() for n in NAMES), 'Existing resources: refuse overwrite'
        for stage in range(1, 5):
            data = (source / f'PIC{stage}.BMP').read_bytes()
            assert data[:2] == b'BM' and tuple(data[6:8]) == (spec['hazard'], stage)
            assert struct.unpack_from('<iiHHI', data, 18) == (640, 480, 1, 32, 0)
            assert len(data) == 1228854
        font, text, meta = encode_text(spec, [{'name': t} for t in spec['titles']])
        validate_text(font, text, meta)
        bundles[folder] = (font, text, meta)
    pcm = {}
    for stage in range(1, 5):
        fixed = ROOT / f'tools/publicity/geohazard_release/cards/demo/card/SND{stage}.PCM'
        data = fixed.read_bytes()
        assert len(data) == 768000 and any(data)
        wavpath = ROOT / f'tools/scenes/classroom_audio/stage{stage}.wav'
        if wavpath.is_file():
            with wave.open(str(wavpath), 'rb') as wav:
                assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) == (1, 2, 48000, 'NONE')
                assert wav.getnframes() == 384000
                assert data == wav.readframes(wav.getnframes())
        pcm[f'SND{stage}.PCM'] = data
    out.mkdir(parents=True)
    records = {}
    for folder, (font, text, meta) in bundles.items():
        dest = out / folder
        dest.mkdir()
        payloads = {'FONT.BIN': font, 'TEXT.BIN': text, **pcm}
        for name, data in payloads.items():
            (dest / name).write_bytes(data)
        write_json(dest / 'text_metadata.json', meta)
        records[folder] = {'text': meta['segments'], 'font_glyphs': len(font)//32,
                           'files': {name: len(data) for name, data in payloads.items()}}
    write_json(out / 'manifest.json', {'card': str(card), 'format': '48kHz mono s16le raw PCM',
        'audio': 'v0.18 M6 original classroom cues; SND4 looping siren, not narration',
        'audio_seconds_each': 8, 'rtl_and_bit_changed': False, 'scenes': records,
        'status': 'prepared; simulation and card write pending'})
    print(f'PASS prepared {len(bundles)} FONT/TEXT pairs and 16 original PCM cues: {out}')


def install(card, out):
    manifest = json.loads((out / 'manifest.json').read_text(encoding='utf-8'))
    assert card.resolve() == Path(manifest['card']).resolve()
    targets = [(card / f / n, out / f / n) for f in manifest['scenes'] for n in NAMES]
    assert all(not dst.exists() and src.is_file() for dst, src in targets), 'Never overwrite existing card resources'
    # Include all ordinary scene/publicity resources, not Windows system metadata.
    existing = {p: p.read_bytes() for folder in ('情景模式', '宣讲模式')
                for p in (card.parent / folder).rglob('*') if p.is_file()}
    write_json(out / 'before_write.json', {str(p): len(data) for p, data in existing.items()})
    for dst, src in targets:
        with dst.open('xb') as stream:
            stream.write(src.read_bytes())
            stream.flush()
            os.fsync(stream.fileno())
    for dst, src in targets:
        assert dst.read_bytes() == src.read_bytes(), dst
    for path, data in existing.items():
        assert path.read_bytes() == data, f'Existing file changed: {path}'
    after = {p for folder in ('情景模式', '宣讲模式')
             for p in (card.parent / folder).rglob('*') if p.is_file()}
    assert after == set(existing) | {dst for dst, _ in targets}
    write_json(out / 'card_write_result.json', {
        'added_files': [str(dst) for dst, _ in targets], 'added_count': len(targets),
        'all_added_files_byte_equal': True, 'unchanged_existing_files': len(existing),
        'unchanged_existing_bytes': sum(map(len, existing.values())),
        'existing_files_byte_equal': True, 'board_display_and_audio': 'pending'})
    print(f'PASS wrote/read back {len(targets)} new files; {len(existing)} existing files byte-unchanged')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('prepare', 'install'))
    p.add_argument('--card', type=Path, default=Path('G:/情景模式'))
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    (prepare if args.action == 'prepare' else install)(args.card, args.output)
