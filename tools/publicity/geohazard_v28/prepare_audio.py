"""Trim/normalise MiniMax narration WAVs into inputs/narration1-4.wav.

Run: <scoop python> -I -X utf8 tools/publicity/geohazard_v28/prepare_audio.py SRC_DIR
SRC_DIR holds 滑坡/泥石流/山洪/地震.wav (48 kHz mono 16-bit, MiniMax export);
a page without a WAV may be an .mp3, decoded with ffmpeg to 48 kHz mono.
Uses scene_audio.shape(): 20 ms around the voice, peak ~ -1 dBFS.
"""
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NAMES = ['滑坡', '泥石流', '山洪', '地震']
LIMIT_S = 4095 * 420000 / 25e6     # PS1 frames field: ~68.8 s


def scene_audio():
    sys.path.insert(0, str(ROOT / 'tools'))
    spec = importlib.util.spec_from_file_location('scene_audio', ROOT / 'tools/mountain_port/scene_audio.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load(sa, src, name):
    """NAME.wav (48 kHz mono 16-bit) if present, else NAME.mp3 via ffmpeg."""
    wav = src / f'{name}.wav'
    if wav.exists():
        return wav.name, sa.read_wav48(wav)
    mp3 = src / f'{name}.mp3'
    with tempfile.TemporaryDirectory() as work:
        out = Path(work) / 'decoded.wav'
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(mp3), '-ac', '1', '-ar', str(sa.SAMPLE_HZ),
                        '-sample_fmt', 's16', str(out)], check=True)
        return mp3.name, sa.read_wav48(out)


def main():
    src = Path(sys.argv[1])
    sa = scene_audio()
    report = []
    for i, name in enumerate(NAMES, 1):
        source, raw = load(sa, src, name)
        raw = raw.astype('int32')
        pcm = sa.shape(raw)
        seconds = len(pcm) / sa.SAMPLE_HZ
        assert 20 < seconds < LIMIT_S, (name, seconds)
        sa.write_wav48(HERE / f'inputs/narration{i}.wav', pcm)
        report.append({'page': i, 'source': source, 'source_seconds': round(len(raw) / 48000, 3),
                       'seconds': round(seconds, 3), 'peak': int(abs(pcm).max())})
        print(f'page{i} {name}: {report[-1]["source_seconds"]}s -> {report[-1]["seconds"]}s')
    (HERE / 'inputs/voice.json').write_text(json.dumps(
        {'engine': 'MiniMax (user-generated, web)', 'shaping': 'scene_audio.shape: trim 20 ms, peak 29000',
         'pages': report}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
