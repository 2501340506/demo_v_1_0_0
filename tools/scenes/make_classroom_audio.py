"""Reproducible classroom cues and a looping SND4 alarm (not narration)."""
import argparse
import math
from pathlib import Path
import struct
import wave


def generate(folder):
    folder = Path(folder)
    paths = [folder / f'stage{s}.wav' for s in range(1, 5)]
    if any(p.exists() for p in paths):
        raise FileExistsError('choose a fresh audio directory')
    folder.mkdir(parents=True, exist_ok=True)
    for stage, path in enumerate(paths, 1):
        samples = []
        for i in range(8 * 48000):
            t = i / 48000
            if stage == 4:
                # FM siren 600..1000 Hz, four smooth up/down cycles in 8 s.
                phase = 2 * math.pi * 800 * t - 400 * math.cos(math.pi * t)
                envelope = min(1, t / .03, (8 - 1 / 48000 - t) / .03)
            else:
                at = t % 4
                envelope = max(0, min(1, at / .02, (.3-at) / .02)) if at < .3 else 0
                phase = 2 * math.pi * (220 + 110 * stage) * t
            samples.append(round(9000 * envelope * math.sin(phase)))
        with wave.open(str(path), 'wb') as wav:
            wav.setparams((1, 2, 48000, len(samples), 'NONE', 'not compressed'))
            wav.writeframes(struct.pack(f'<{len(samples)}h', *samples))
        print(path)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'classroom_audio')
    generate(parser.parse_args().output)
