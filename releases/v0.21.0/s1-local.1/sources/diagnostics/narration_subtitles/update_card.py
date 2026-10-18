"""Snapshot card media, then install only PS1 TEXT after a clean bit is frozen.

No hashes. Preserve all existing media and compare every other byte to the
snapshot. System Volume Information is outside the application media scope.
"""
import argparse
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
FOLDERS=('宣讲模式','情景模式')


def media(card):
    return sorted(p.relative_to(card) for name in FOLDERS for p in (card/name).rglob('*') if p.is_file())


def snapshot(card, backup):
    assert not backup.exists(), 'Choose a new backup directory'
    files=media(card)
    assert files and (card/'宣讲模式/TEXT.BIN').exists()
    for rel in files:
        target=backup/'before'/rel
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(card/rel,target)
        assert target.read_bytes()==(card/rel).read_bytes()
    report=dict(card=str(card), files=[dict(file=p.as_posix(),bytes=(card/p).stat().st_size) for p in files])
    (backup/'snapshot.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS snapshot: {len(files)} application media files byte-compared')


def install(card,backup,candidate):
    assert (candidate/'demo.bit').stat().st_size>100000
    manifest=json.loads((candidate/'MANIFEST.json').read_text(encoding='utf-8'))
    assert manifest['timing_ns']['SWNS']>0 and manifest['timing_ns']['HWNS']>0
    before=backup/'before';files=media(card)
    assert files==media(before), 'Media file set changed since snapshot'
    for rel in files:
        assert (card/rel).read_bytes()==(before/rel).read_bytes(), str(rel)
    # Narration timing is based on these exact PCM streams.
    for i in range(1,5):
        assert (card/f'宣讲模式/VOI{i}.PCM').read_bytes()==(ROOT/f'tools/publicity/geohazard_release/generated/VOI{i}.PCM').read_bytes()
        assert (card/f'宣讲模式/EDU{i}.BMP').read_bytes()==(ROOT/f'releases/v0.20.0/s1-local.1/card/EDU{i}.BMP').read_bytes()
    rel=Path('宣讲模式/TEXT.BIN');source=candidate/'card/TEXT.BIN'
    assert source.read_bytes().startswith(b'PS\x01\x04')
    shutil.copyfile(source,card/rel)
    assert (card/rel).read_bytes()==source.read_bytes()
    assert media(card)==files
    unchanged=[]
    for other in files:
        if other!=rel:
            assert (card/other).read_bytes()==(before/other).read_bytes(), str(other)
            unchanged.append(other.as_posix())
    report=dict(updated=rel.as_posix(),bytes=source.stat().st_size,readback='byte identical',
                unchanged_byte_compared=unchanged,backup=str(before/rel),candidate=str(candidate),board_status='pending')
    (backup/'card_write_result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS installed {rel}, {source.stat().st_size} bytes; {len(unchanged)} other media files byte unchanged')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['snapshot','install'])
    p.add_argument('--card',type=Path,default=Path('G:/'))
    p.add_argument('--backup',type=Path,required=True)
    p.add_argument('--candidate',type=Path)
    a=p.parse_args()
    if a.action=='snapshot':snapshot(a.card,a.backup)
    else:install(a.card,a.backup,a.candidate)
