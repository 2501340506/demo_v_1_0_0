"""v0.25 S2: narrated FONT/TEXT/SND1-4 for the four SW3 scene folders.

prepare: read tools/mountain_port/scenes/<folder>/scene.yaml (village,
warning, each stage's title/subtitle and narration recordings) and write
<output>/<folder>/{FONT.BIN,TEXT.BIN,SND1-4.PCM}, listening copies in
<output>/<folder>/audio/ and <output>/manifest.json. Everything is checked
before anything is written; the output directory must be new.

install: replace those six files in <card>/<folder>. The files being replaced
are first copied to <output>/backup/<folder>/ (restore by copying them back);
written files are read back, and every other file under the card's
情景模式 and 宣讲模式 folders must stay byte-identical.

With --legends the stage's `legend: [[swatch, text], ...]` is written as well (TEXT.BIN with
14 segments, one 16 px legend line per stage, at most 38 cells as in the reference project).

As in the reference project, a stage without `subtitle:` uses its whole narration as the
subtitle (the lines' text joined by two spaces).

Display limits (scene_text_overlay, 16 px cells): the title and the village name sit in
the 256 px wide top-right panel (at most 16 characters); the subtitle, and the warning
in warning mode, move left through the bottom band at 2 px per frame (60 frames per
second), so the last of n characters has come in after 16n/120 s: at most 60 characters
are all shown within one 8.5 s stage.

Firmware: segments longer than 31 characters (the narration subtitles) and the 14-segment
legend file need the v0.25 S5 firmware; older firmware rejects them and shows no text.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import sys

import numpy as np
import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(HERE))
from scene_text import encode_text, legend_string, ESCAPES, FULLWIDTH, SWATCH_CHARS  # noqa: E402
import scene_audio  # noqa: E402

FOLDERS = {'landslide_village': 1, 'debris_village': 2, 'flood_village': 3, 'quake_village': 4}
NAMES = ['FONT.BIN', 'TEXT.BIN'] + [f'SND{i}.PCM' for i in range(1, 5)]
TITLE_CELLS, SUBTITLE_CELLS, WARNING_CELLS, LEGEND_CELLS = 16, 60, 60, 38
MIN_SAMPLES = scene_audio.T_END * scene_audio.SAMPLES_PER_T + scene_audio.SAMPLE_HZ // 2


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def normal(s):
    return ''.join(FULLWIDTH.get(c, c) for c in str(s))


def stage_subtitle(stage):
    """The stage's subtitle: `subtitle:` if given, else its narration lines joined by two spaces."""
    if stage.get('subtitle'):
        return str(stage['subtitle'])
    return '  '.join(str(line['text']) for line in sorted(stage.get('narration') or [], key=lambda d: d['t']))


def text_spec(cfg, where, legends=False):
    stages = cfg['stages']
    assert len(stages) == 4, f'{where}: four stages'
    spec = {'titles': [normal(s['title']) for s in stages], 'subtitles': [normal(stage_subtitle(s)) for s in stages],
            'warning': normal(cfg['warning']), 'village': normal(cfg['village'])}
    if legends:
        spec['legends'] = [legend_string(s.get('legend'), f'{where}: stage {n + 1} legend') for n, s in enumerate(stages)]
        for v in spec['legends']:
            assert len(v) <= LEGEND_CELLS, f'{where}: legend {v!r} has {len(v)} cells (at most {LEGEND_CELLS})'
        if not any(spec['legends']):
            del spec['legends']
    for label, values, limit in (('title', spec['titles'], TITLE_CELLS), ('subtitle', spec['subtitles'], SUBTITLE_CELLS),
                                 ('warning', [spec['warning']], WARNING_CELLS), ('village', [spec['village']], TITLE_CELLS)):
        for v in values:
            assert 0 < len(v) <= limit, f'{where}: {label} {v!r} has {len(v)} characters (1..{limit})'
    return spec


def validate_text(font, text, meta, spec):
    assert 416 <= len(font) <= 4096 and len(font) % 32 == 0 and len(font) // 32 <= 128
    wanted = [v for pair in zip(spec['titles'], spec['subtitles']) for v in pair] + [spec['warning'], spec['village']]
    wanted += spec.get('legends', [])
    assert text[:3] == b'TX\x01' and text[3] == len(wanted) and len(text) <= 4096
    assert meta['segments'] == wanted
    slots = {v: k for k, v in meta['slots'].items()}
    cursor = 4 + 4 * len(wanted)
    for i, segment in enumerate(wanted):
        at, count, kind = struct.unpack_from('<HBB', text, 4 + 4 * i)
        assert (at, count, kind) == (cursor, len(segment), i % 2 if i < 8 else i - 6 if i < 10 else 4)
        codes = text[at:at + count]
        assert ''.join(slots[c] if c < 128 else SWATCH_CHARS[c - 0xe0] if 0xe0 <= c < 0xe8 else ESCAPES[c - 240]
                       for c in codes) == segment
        assert all(any(font[c * 32:(c + 1) * 32]) for c in codes if c < 128), f'empty glyph in {segment!r}'
        cursor += count
    assert cursor == len(text)


def check_card_pictures(folder_path, hazard):
    for stage in range(1, 5):
        data = (folder_path / f'PIC{stage}.BMP').read_bytes()
        assert data[:2] == b'BM' and tuple(data[6:8]) == (hazard, stage), folder_path / f'PIC{stage}.BMP'
        assert struct.unpack_from('<iiHHI', data, 18) == (640, 480, 1, 32, 0) and len(data) == 1228854


def prepare(out, legends=False):
    assert not out.exists(), 'Choose a fresh output directory'
    bundles, records = {}, {}
    for folder in FOLDERS:
        base_dir = HERE / 'scenes' / folder
        cfg = yaml.safe_load((base_dir / 'scene.yaml').read_text(encoding='utf-8'))
        spec = text_spec(cfg, folder, legends)
        font, text, meta = encode_text(spec, cfg['stages'])
        validate_text(font, text, meta, spec)
        tracks = scene_audio.stage_tracks(cfg, base_dir, tts=False)
        sounds, stages = {}, []
        for n, (pcm, notes, placements) in enumerate(tracks):
            assert pcm is not None, f'{folder} stage {n + 1}: no audio'
            assert len(pcm) >= MIN_SAMPLES, f'{folder} stage {n + 1}: {len(pcm)} samples'
            assert placements and all(p['source'] not in ('beep', 'sapi') for p in placements), \
                f'{folder} stage {n + 1}: every narration line needs a recording'
            assert not any(x.startswith('clipped') for x in notes), f'{folder} stage {n + 1}: {notes}'
            sounds[f'SND{n + 1}.PCM'] = pcm
            stages.append({'title': spec['titles'][n], 'subtitle': spec['subtitles'][n], 'notes': notes,
                           'seconds': round(len(pcm) / scene_audio.SAMPLE_HZ, 3),
                           'speech_end_t': round(max(p['start'] + p['samples'] for p in placements) / scene_audio.SAMPLES_PER_T, 1),
                           'lines': placements})
        bundles[folder] = (font, text, meta, sounds)
        records[folder] = {'village': spec['village'], 'warning': spec['warning'], 'font_glyphs': len(font) // 32,
                           'text_bytes': len(text), 'stages': stages}
    out.mkdir(parents=True)
    for folder, (font, text, meta, sounds) in bundles.items():
        dest = out / folder
        (dest / 'audio').mkdir(parents=True)
        payloads = {'FONT.BIN': font, 'TEXT.BIN': text, **{k: v.tobytes() for k, v in sounds.items()}}
        for name, data in payloads.items():
            (dest / name).write_bytes(data)
        for name, pcm in sounds.items():
            scene_audio.write_wav48(dest / 'audio' / name.replace('.PCM', '.wav'), pcm)
        write_json(dest / 'text_metadata.json', meta)
        records[folder]['files'] = {name: {'bytes': len(data), 'sha256': sha(data)} for name, data in payloads.items()}
    write_json(out / 'manifest.json', {'format': '48 kHz mono s16le raw PCM; TEXT.BIN v1 (10 segments)',
        'audio': 'reference-project MiniMax narration at t*1600 samples; SND4 adds the v0.18 M6 siren at gain 0.3, looped',
        'rtl_and_bit_changed': False, 'scenes': records, 'status': 'prepared; card write pending'})
    for folder, record in records.items():
        print(folder, record['font_glyphs'], 'glyphs', ' / '.join(f"{s['seconds']}s" for s in record['stages']))
    print(f'PASS prepared {len(bundles)} narrated scene folders: {out}')


def install(card, out):
    manifest = json.loads((out / 'manifest.json').read_text(encoding='utf-8'))
    backup = out / 'backup'
    assert not backup.exists(), 'This output was already installed'
    targets = []
    for folder in manifest['scenes']:
        check_card_pictures(card / folder, FOLDERS[folder])
        for name in NAMES:
            src = (out / folder / name).read_bytes()
            assert sha(src) == manifest['scenes'][folder]['files'][name]['sha256'], out / folder / name
            targets.append((card / folder / name, src))
    watched = {p: p.read_bytes() for top in ('情景模式', '宣讲模式') for p in (card.parent / top).rglob('*') if p.is_file()}
    replaced = {dst: watched[dst] for dst, _ in targets if dst in watched}
    for dst, data in replaced.items():
        keep = backup / dst.parent.name / dst.name
        keep.parent.mkdir(parents=True, exist_ok=True)
        with keep.open('xb') as stream:
            stream.write(data)
    write_json(out / 'before_write.json', {str(p): {'bytes': len(d), 'sha256': sha(d)} for p, d in watched.items()})
    for dst, data in targets:
        with dst.open('wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    for dst, data in targets:
        assert dst.read_bytes() == data, dst
    target_set = {dst for dst, _ in targets}
    for path, data in watched.items():
        if path not in target_set:
            assert path.read_bytes() == data, f'Existing file changed: {path}'
    after = {p for top in ('情景模式', '宣讲模式') for p in (card.parent / top).rglob('*') if p.is_file()}
    assert after == set(watched) | target_set
    write_json(out / 'card_write_result.json', {
        'written_files': [str(dst) for dst, _ in targets], 'replaced_with_backup': [str(p) for p in replaced],
        'added': [str(p) for p in target_set - set(replaced)], 'all_written_files_byte_equal': True,
        'unchanged_other_files': len(watched) - len(replaced), 'backup': str(backup),
        'board_display_and_audio': 'pending'})
    print(f'PASS wrote/read back {len(targets)} files ({len(replaced)} replaced, backup in {backup}); '
          f'{len(watched) - len(replaced)} other files byte-unchanged')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('action', choices=('prepare', 'install'))
    p.add_argument('--card', type=Path, help='install: the card\'s 情景模式 folder')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--legends', action='store_true', help='prepare: also write the stage legends (v0.25 S5 firmware)')
    args = p.parse_args()
    if args.action == 'prepare':
        prepare(args.output, args.legends)
    else:
        if not args.card:
            p.error('install needs --card')
        install(args.card, args.output)
