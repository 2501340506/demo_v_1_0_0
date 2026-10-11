#!/usr/bin/env python3
"""Convert an input audio file to the board's fixed 48 kHz mono PCM format."""
from pathlib import Path
import argparse, subprocess, wave

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input'); ap.add_argument('output')
    a=ap.parse_args(); src=Path(a.input); dst=Path(a.output)
    dst.parent.mkdir(parents=True, exist_ok=True)
    cmd=['ffmpeg','-y','-v','error','-i',str(src),'-f','s16le','-acodec','pcm_s16le','-ac','1','-ar','48000',str(dst)]
    subprocess.run(cmd,check=True)
    size=dst.stat().st_size
    print(f'{dst}: {size} bytes, {size//2} samples, {size/2/48000:.3f} seconds')
if __name__=='__main__': main()
