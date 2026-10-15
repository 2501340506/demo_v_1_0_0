#!/usr/bin/env python3
"""Convert an input audio file to the board's fixed 48 kHz mono PCM format."""
from pathlib import Path
import argparse, subprocess, wave

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input'); ap.add_argument('output')
    ap.add_argument('--force', action='store_true', help='replace an existing output file')
    a=ap.parse_args(); src=Path(a.input); dst=Path(a.output)
    if src.resolve() == dst.resolve(): ap.error('input and output must differ')
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and not a.force: ap.error('output already exists')
    # Exact-format WAV needs no resampling. This also supports scene-pack demo
    # generation on machines without ffmpeg; all other formats use ffmpeg.
    if src.suffix.lower() == '.wav':
        with wave.open(str(src), 'rb') as wav:
            if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) == (1, 2, 48000, 'NONE'):
                payload = wav.readframes(wav.getnframes())
                if not payload or len(payload) != wav.getnframes() * 2: ap.error('empty or truncated WAV')
                with dst.open('wb' if a.force else 'xb') as output: output.write(payload)
                print(f'{dst}: {len(payload)} bytes, exact-format WAV extraction')
                return
    cmd=['ffmpeg','-y' if a.force else '-n','-v','error','-i',str(src),'-f','s16le','-acodec','pcm_s16le','-ac','1','-ar','48000',str(dst)]
    subprocess.run(cmd,check=True)
    size=dst.stat().st_size
    print(f'{dst}: {size} bytes, {size//2} samples, {size/2/48000:.3f} seconds')
if __name__=='__main__': main()
