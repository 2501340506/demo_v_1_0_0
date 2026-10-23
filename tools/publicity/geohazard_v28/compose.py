"""Compose v0.28 publicity pages: full-bleed AI illustration + code-drawn marks.

Run: <scoop python> -I -X utf8 tools/publicity/geohazard_v28/compose.py --art ART_DIR --output NEW [--pages 1]
ART_DIR holds pageN.png (3:2 AI image, not in repo).  Callout/arrow positions
are 640x420 page coordinates in content.yaml `marks` (they belong to that art).
Writes inputs/pageN.png (640x480 pack input), preview/pageN_sim.png (simulated
subtitle + waveform) and generation.json.
"""
import argparse
import json
import math
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONTS = Path('C:/Windows/Fonts')
BOTTOM = (244, 246, 237)           # same subtitle/waveform ground as v0.20-v0.27
INK = (40, 36, 32)
STATUS = (400, 8, 608, 24)         # BUSY/ERROR overlay; title tag stays left of it
TEXT_LIMIT = 418                   # subtitles start at y422
GO, STOP = (34, 160, 70), (220, 40, 40)


def font(bold, size):
    return ImageFont.truetype(str(FONTS / ('msyhbd.ttc' if bold else 'msyh.ttc')), size)


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


class Page:
    def __init__(self, art_path):
        art = Image.open(art_path).convert('RGB')
        art = art.resize((640, round(art.height * 640 / art.width)), Image.LANCZOS)
        top = max(0, (art.height - 420) // 2)
        self.im = Image.new('RGB', (640, 480), BOTTOM)
        self.im.paste(art.crop((0, top, 640, top + 420)), (0, 0))
        self.bounds = []

    def merge(self, layer):
        self.im = Image.alpha_composite(self.im.convert('RGBA'), layer).convert('RGB')

    def text(self, draw, xy, value, f, fill, anchor='la'):
        box = draw.textbbox(xy, value, font=f, anchor=anchor)
        assert 0 <= box[0] and box[2] <= 640 and box[3] <= TEXT_LIMIT, (value, box)
        assert not (box[2] > STATUS[0] and box[1] < STATUS[3] and box[3] > STATUS[1]), (value, box)
        draw.text(xy, value, font=f, fill=fill, anchor=anchor)
        self.bounds.append({'text': value, 'box': list(box)})


def pill(draw, box, fill, radius=None, outline=None):
    draw.rounded_rectangle(box, radius or (box[3] - box[1]) // 2, fill=fill, outline=outline,
                           width=2 if outline else 0)


def arrow(draw, points, color, width=9):
    """Thick polyline with a triangular head at the last point, white-edged."""
    (x0, y0), (x1, y1) = points[-2], points[-1]
    a = math.atan2(y1 - y0, x1 - x0)
    c, s = math.cos(a), math.sin(a)

    def head(k):
        return [(x1 + (4 + k) * c, y1 + (4 + k) * s),
                (x1 - (22 + k) * c + (15 + k) * s, y1 - (22 + k) * s - (15 + k) * c),
                (x1 - (22 + k) * c - (15 + k) * s, y1 - (22 + k) * s + (15 + k) * c)]
    body = points[:-1] + [(x1 - 16 * c, y1 - 16 * s)]
    draw.line(body, fill='white', width=width + 6, joint='curve')
    draw.polygon(head(3), fill='white')
    draw.line(body, fill=color, width=width, joint='curve')
    draw.polygon(head(0), fill=color)


def compose(page):
    p = Page(page['art'])
    color = rgb(page['color'])
    marks = page['marks']
    ov = Image.new('RGBA', (640, 480), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)

    # Wrong-way (red) and escape (green) arrows, as in scene stage 4.
    for kind, key in ((STOP, 'wrong'), (GO, 'escape')):
        spec = marks[key]
        arrow(d, [tuple(q) for q in spec['path']], kind)
        x, y = spec['label_at']
        f = font(True, 17)
        label = spec['text']
        w = d.textlength(label, font=f)
        pill(d, (x - w / 2 - 10, y - 14, x + w / 2 + 10, y + 14), kind + (240,), outline='white')
        p.text(d, (x, y), label, f, 'white', 'mm')

    # Warning-sign callouts: ring on the feature, leader line, numbered bubble.
    amber = (230, 150, 20)
    f = font(True, 16)
    for n, (target, at, value) in enumerate(marks['signs'], 1):
        (tx, ty), (bx, by) = target, at
        d.line((tx, ty, bx, by), fill='white', width=4)
        d.line((tx, ty, bx, by), fill=amber, width=2)
        d.ellipse((tx - 11, ty - 11, tx + 11, ty + 11), outline='white', width=5)
        d.ellipse((tx - 11, ty - 11, tx + 11, ty + 11), outline=amber, width=3)
        w = d.textlength(value, font=f)
        pill(d, (bx - 4, by - 13, bx + w + 30, by + 13), (255, 255, 255, 240), outline=amber)
        d.ellipse((bx, by - 10, bx + 20, by + 10), fill=amber)
        p.text(d, (bx + 10, by), str(n), font(True, 13), 'white', 'mm')
        p.text(d, (bx + 25, by), value, f, INK, 'lm')

    # Title tag (left of the status overlay).
    big, small = font(True, 30), font(True, 18)
    head, slogan = page['title'].split('：')
    w1, w2 = d.textlength(head, font=big), d.textlength(slogan, font=small)
    pill(d, (8, 8, 60 + w1 + w2, 54), color + (245,), radius=14, outline='white')
    p.text(d, (22, 31), str(page['id']), font(True, 14), 'white', 'mm')
    p.text(d, (34, 31), head, big, 'white', 'lm')
    p.text(d, (46 + w1, 32), slogan, small, 'white', 'lm')

    # Real-case chip under the status overlay.
    x0, y0 = marks.get('case_at', (404, 30))
    lines, cf = page['case_lines'], font(False, 13)
    w = max(d.textlength(s, font=cf) for s in lines)
    d.rounded_rectangle((x0, y0, x0 + w + 20, y0 + 26 + 17 * len(lines)), 10,
                        fill=(255, 255, 255, 225), outline=color, width=2)
    p.text(d, (x0 + 10, y0 + 5), '真实案例', font(True, 13), color)
    for i, s in enumerate(lines):
        p.text(d, (x0 + 10, y0 + 23 + 17 * i), s, cf, INK)

    # Rhyme banner along the bottom of the picture.
    d.rounded_rectangle((8, 384, 632, 416), 16, fill=color + (235,), outline='white', width=2)
    p.text(d, (40, 400), '口诀', font(True, 15), 'white', 'mm')
    d.line((66, 390, 66, 410), fill='white', width=2)
    p.text(d, (350, 400), page['rhyme'], font(True, 21), 'white', 'mm')

    p.merge(ov)
    ImageDraw.Draw(p.im).rectangle((0, 420, 639, 479), fill=BOTTOM)
    assert set(p.im.crop((0, 420, 640, 480)).get_flattened_data()) == {BOTTOM}
    return p.im, p.bounds


def simulate(im, script):
    """Approximate board look: 21px black SimSun subtitle + max white waveform."""
    sim = im.copy()
    draw = ImageDraw.Draw(sim)
    draw.text((8, 422), script[:29], font=ImageFont.truetype(str(FONTS / 'simsun.ttc'), 21), fill='black')
    for x in range(640):
        env = 1 - ((x - 320) / 320) ** 2
        h = int(14 * env * env) + 1
        draw.line((x, 465 + h, x, 479), fill=(170, 200, 240))
        draw.line((x, 464 - h, x, 464 + h), fill='white')
    return sim


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--art', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pages', type=int, nargs='*', default=[1, 2, 3, 4])
    parser.add_argument('--marks', type=Path, default=HERE / 'marks.yaml', help='marks yaml {page_id: marks}')
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a new output directory'
    spec = yaml.safe_load((HERE / 'content.yaml').read_text(encoding='utf-8'))
    override = yaml.safe_load(args.marks.read_text(encoding='utf-8'))
    (args.output / 'inputs').mkdir(parents=True)
    (args.output / 'preview').mkdir()
    report = {'edition': spec['edition'], 'pages': []}
    for page in spec['pages']:
        if page['id'] not in args.pages:
            continue
        page = dict(page, art=args.art / f"page{page['id']}.png")
        page['marks'] = override[page['id']]
        im, bounds = compose(page)
        im.save(args.output / f"inputs/page{page['id']}.png")
        script = (HERE / f"scripts/page{page['id']}.txt").read_text(encoding='utf-8').strip()
        simulate(im, script).save(args.output / f"preview/page{page['id']}_sim.png")
        report['pages'].append({'id': page['id'], 'marks': page['marks'], 'text_bounds': bounds})
    (args.output / 'generation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n',
                                                 encoding='utf-8')
    print(f"PASS composed pages {args.pages}: text within y<={TEXT_LIMIT}, bottom band clear")


if __name__ == '__main__':
    main()
