"""Deterministic placeholder effects, NOT narration or hazard predictions."""
from pathlib import Path
import math
import struct
import wave

folder = Path(__file__).resolve().parent
for stage, frequency in enumerate((330, 440, 550, 660), 1):
    destination = folder / f"placeholder{stage}.wav"
    if destination.exists():
        raise FileExistsError(destination)
    samples = []
    for index in range(8 * 48000):
        # Eight seconds; short tones mark t~=0/120 at 1x. Silent endpoints
        # make the looping corpus continuous without inventing narration.
        at = index / 48000
        phase = at % 4
        envelope = max(0.0, min(1.0, phase / .02, (.3-phase) / .02)) if phase < .3 else 0.0
        samples.append(int(9000 * envelope * math.sin(2 * math.pi * frequency * at)))
    with wave.open(str(destination), 'wb') as wav:
        wav.setparams((1, 2, 48000, len(samples), 'NONE', 'not compressed'))
        wav.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    print(destination)
