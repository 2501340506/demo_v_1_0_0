from pathlib import Path
import json
import sys
root = Path(__file__).resolve().parents[2]
source = root / 'tools/scenes/demo_village/generated_m5'
fixed = root / 'releases/v0.17.0/m5-local.1/board_samples'
if fixed.is_dir():
    source = fixed
if len(sys.argv) > 2:
    source = Path(sys.argv[2])
out = Path(sys.argv[1])
sizes = {}
for stem in ('FONT', 'TEXT'):
    data = (source / (stem + '.BIN')).read_bytes()
    sizes[stem.lower()] = len(data)
    (out / (stem.lower() + '.hex')).write_text(''.join(f'{b:02x}\n' for b in data.ljust(4096, b'\0')), encoding='ascii')
(out / 'sizes.json').write_text(json.dumps(sizes), encoding='ascii')
