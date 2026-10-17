"""Regenerate four supplied packs and compare bytes, then build pixel vectors."""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[2]
out = root / 'diagnostics/output/disaster_s1_vectors01'
package = Path(sys.argv[1])
cards = ('landslide_village', 'debris_village', 'flood_village', 'quake_village')
for card in cards:
    subprocess.run([sys.executable, '-I', '-X', 'utf8', str(root/'tools/mountain_port/make_scene_pack.py'),
                    str(root/'tools/mountain_port/scenes'/card/'scene.yaml'), '--out', str(out/card)], check=True)
    for n in range(1, 5):
        data = (out/card/'sd'/f'PIC{n}.BMP').read_bytes()
        assert data == (package/'sd_cards'/card/f'PIC{n}.BMP').read_bytes(), (card,n)
        assert data == (Path('G:/情景模式')/card/f'PIC{n}.BMP').read_bytes(), (card,n,'card')
    print('PASS byte comparison', card)
subprocess.run([sys.executable, '-I', '-X', 'utf8', str(root/'diagnostics/disaster_selector/make_hazard_vectors3.py'),
                str(out/'vectors'), *(str(out/card) for card in cards)], check=True)
