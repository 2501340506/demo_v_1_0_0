#!/usr/bin/env python3
"""Convert an input audio file to the board's fixed 48 kHz mono PCM format."""
from pathlib import Path
import argparse, subprocess, wave

def convert(src, dst, force=False):
    """src -> dst as raw s16le, 48 kHz, mono. Returns (bytes, how); how is
    'wav' for an exact-format WAV copied without ffmpeg, else 'ffmpeg'."""
    src, dst = Path(src), Path(dst)
    if src.resolve() == dst.resolve(): raise ValueError('input and output must differ')
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and not force: raise FileExistsError('output already exists')
    # Exact-format WAV needs no resampling. This also supports scene-pack demo
    # generation on machines without ffmpeg; all other formats use ffmpeg.
    if src.suffix.lower() == '.wav':
        with wave.open(str(src), 'rb') as wav:
            if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) == (1, 2, 48000, 'NONE'):
                payload = wav.readframes(wav.getnframes())
                if not payload or len(payload) != wav.getnframes() * 2: raise ValueError('empty or truncated WAV')
                with dst.open('wb' if force else 'xb') as output: output.write(payload)
                return len(payload), 'wav'
    cmd=['ffmpeg','-y' if force else '-n','-v','error','-i',str(src),'-f','s16le','-acodec','pcm_s16le','-ac','1','-ar','48000',str(dst)]
    subprocess.run(cmd,check=True)
    return dst.stat().st_size, 'ffmpeg'

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input'); ap.add_argument('output')
    ap.add_argument('--force', action='store_true', help='replace an existing output file')
    a=ap.parse_args(); src=Path(a.input); dst=Path(a.output)
    try:
        size, how = convert(src, dst, a.force)
    except (ValueError, FileExistsError) as e:
        ap.error(str(e))
    if how == 'wav':
        print(f'{dst}: {size} bytes, exact-format WAV extraction')
    else:
        print(f'{dst}: {size} bytes, {size//2} samples, {size/2/48000:.3f} seconds')
if __name__=='__main__': main()
