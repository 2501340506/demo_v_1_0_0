"""v0.27 scene OSD/SCROLL gates: compare three renders of the same scene frame.
on.hex has both on, hud.hex has OSD off, sub.hex has SCROLL off. bg.hex is the input.
OSD off must restore the top-right panel and the legend and leave the subtitle;
SCROLL off must restore the subtitle line and leave the panel and legend."""
import sys
from pathlib import Path


def load(p):
    return [int(v, 16) for v in Path(p).read_text().split()]


def region(img, x0, x1, y0, y1):
    return [img[y * 640 + x] for y in range(y0, y1) for x in range(x0, x1)]


d = Path(sys.argv[1])
bg, on, hud, sub = (load(d / n) for n in ('bg.hex', 'on.hex', 'hud.hex', 'sub.hex'))
panel = (348, 636, 28, 60)
legend = (4, 640, 412, 436)
subtitle = (8, 632, 440, 464)
checks = [
    ('panel drawn when on', region(on, *panel) != region(bg, *panel)),
    ('subtitle drawn when on', region(on, *subtitle) != region(bg, *subtitle)),
    ('OSD off clears panel', region(hud, *panel) == region(bg, *panel)),
    ('OSD off clears legend', region(hud, *legend) == region(bg, *legend)),
    ('OSD off keeps subtitle', region(hud, *subtitle) == region(on, *subtitle)),
    ('SCROLL off clears subtitle', region(sub, *subtitle) == region(bg, *subtitle)),
    ('SCROLL off keeps panel', region(sub, *panel) == region(on, *panel)),
    ('SCROLL off keeps legend', region(sub, *legend) == region(on, *legend)),
]
if region(on, *legend) == region(bg, *legend):
    checks.append(('legend drawn when on (card has a legend)', False))
bad = [n for n, ok in checks if not ok]
for n, ok in checks:
    print(('ok   ' if ok else 'FAIL ') + n)
if bad:
    sys.exit(1)
print('PASS scene gates ' + d.name)
