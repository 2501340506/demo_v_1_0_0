"""Count v0.28 narration characters and distinct glyphs against PS1 limits."""
import pathlib, sys
root = pathlib.Path(__file__).resolve().parent
scripts = [(root / f'scripts/page{i}.txt').read_text(encoding='utf-8').strip() for i in range(1, 5)]
ok = True
for i, s in enumerate(scripts, 1):
    flag = 'OK' if len(s) <= 230 else ('WARN' if len(s) <= 255 else 'FAIL')
    ok &= len(s) <= 255
    print(f'page{i}: {len(s)} chars [{flag}]')
glyphs = list(dict.fromkeys(''.join(scripts)))
ok &= len(glyphs) <= 360
print(f'distinct glyphs: {len(glyphs)} (limit 360, ROM max ~390)')
sys.exit(0 if ok else 1)
