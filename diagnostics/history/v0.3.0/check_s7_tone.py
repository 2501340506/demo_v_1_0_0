"""Compare input PCM to an independent 440 Hz/48 kHz sine reference.
check_hdmi_packets.py separately matches every transmitted sample to input.
"""
from pathlib import Path
import math
import sys

samples = []
for line in Path(sys.argv[1]).read_text().splitlines():
    if line.startswith('A '):
        left, right = (int(v, 16) for v in line.split()[1:])
        assert left == right, 'stereo mismatch'
        samples.append(left if left < 32768 else left - 65536)
assert len(samples) == 3200
for n, actual in enumerate(samples):
    index = math.floor(n * 440 / 48000 * 16 + 1e-7) % 16
    value = 12000 * math.sin(2 * math.pi * index / 16)
    expected = int(value + (0.5 if value >= 0 else -0.5))
    assert actual == expected, (n, actual, expected)
assert min(samples) == -12000 and max(samples) == 12000
print('PASS S7 independent 440Hz/48kHz reference: 3200 stereo samples, peaks -12000/+12000; transmitted samples checked separately')
