"""Draw a second fictional village with a north-south river and western refuge."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def generate(folder):
    folder = Path(folder)
    names = ('village.png', 'rainfall.png', 'rainfall_mask.png', 'flood_mask.png')
    if any((folder / n).exists() for n in names):
        raise FileExistsError('choose a fresh map directory')
    folder.mkdir(parents=True, exist_ok=True)
    im = Image.new('RGB', (640, 480), '#e6efd5')
    d = ImageDraw.Draw(im)
    font = ImageFont.load_default(size=15)
    d.polygon([(300, 0), (530, 0), (625, 65), (540, 184), (482, 239), (345, 169)], fill='#b0c593')
    for shift in range(0, 100, 25):
        d.line([(320, 20+shift), (425, 55+shift), (501, 25+shift), (578, 64+shift)], fill='#899e71', width=2)
    valley = [(315, 0), (430, 0), (477, 139), (445, 262), (480, 480), (299, 480), (325, 281), (294, 125)]
    d.polygon(valley, fill='#cedcbc')
    river = [(357, 0), (382, 96), (373, 174), (390, 259), (374, 337), (409, 480)]
    d.line(river, fill='#effaff', width=32)
    d.line(river, fill='#589cc5', width=22)
    d.line(river, fill='#a7d8ea', width=5)
    d.ellipse((31, 160, 219, 344), fill='#b4cf90', outline='#6b8d55', width=3)
    d.ellipse((55, 184, 195, 320), outline='#91ad6c', width=2)
    route = [(490, 350), (473, 295), (422, 265), (354, 251), (293, 247), (218, 245), (126, 246)]
    d.line(route, fill='#a58e6e', width=14)
    d.line(route, fill='#f3e5b6', width=9)
    # Bridge crossing is explicit in the base artwork.
    d.line([(349, 242), (402, 255)], fill='#695441', width=4)
    d.line([(345, 258), (399, 271)], fill='#695441', width=4)
    for x, y in [(477, 326), (511, 350), (464, 377), (522, 398), (498, 298)]:
        d.rectangle((x, y, x+23, y+20), fill='#fff0ce', outline='#795e48')
        d.polygon([(x-3, y), (x+12, y-12), (x+26, y)], fill='#ba7951')
    d.ellipse((116, 236, 136, 256), fill='#f1f8ce', outline='#356a43', width=2)
    d.line((121, 246, 131, 246), fill='#356a43', width=2)
    d.line((126, 241, 126, 251), fill='#356a43', width=2)
    d.rectangle((10, 10, 410, 43), fill='#f6f7ed')
    d.text((20, 17), 'FLOOD VILLAGE | FICTIONAL TRAINING MAP', font=font, fill='#294638')
    for xy, label in [((44, 350), 'WEST HIGH GROUND'), ((470, 440), 'VILLAGE'), ((405, 194), 'RIVER'), ((462, 145), 'SLOPE')]:
        d.text(xy, label, font=font, fill='#294638', stroke_width=1, stroke_fill='#f6f7ed')
    im.save(folder / names[0])
    yy, xx = np.indices((480, 640))
    Image.fromarray(np.clip(yy * 255 // 330, 0, 255).astype('uint8')).save(folder / names[1])
    for name, poly in [(names[2], [(295, 5), (592, 5), (566, 166), (320, 218)]), (names[3], valley)]:
        mask = Image.new('L', (640, 480), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        mask.save(folder / name)
    print(f'PASS second fictional map: {folder}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).parent)
    generate(parser.parse_args().output)
