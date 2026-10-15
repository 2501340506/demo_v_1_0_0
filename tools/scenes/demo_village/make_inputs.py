"""Draw reproducible fictional teaching artwork; refuses to replace any asset."""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def make_inputs(folder):
    folder = Path(folder)
    names = ("village.png", "rainfall.png", "rainfall_mask.png", "flood_mask.png")
    if any((folder / name).exists() for name in names):
        raise ValueError("input assets already exist; choose a new directory")
    folder.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGB", (640, 480), "#dcebc6")
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=17)
    small = ImageFont.load_default(size=13)
    # Ridge lines, a slope, a river valley, village buildings and safe highland.
    draw.polygon([(0, 54), (94, 22), (194, 72), (278, 30), (364, 104), (319, 208),
                  (252, 278), (149, 222), (0, 256)], fill="#a7bd85")
    for shift in (0, 30, 60, 90):
        draw.line([(12, 82+shift), (91, 52+shift), (178, 105+shift),
                   (260, 77+shift), (318, 125+shift)], fill="#889e6c", width=2)
    valley = [(80, 142), (140, 133), (221, 207), (257, 248), (329, 279),
              (388, 314), (461, 378), (532, 454), (474, 480), (402, 418),
              (333, 366), (266, 329), (209, 278), (149, 250), (95, 198)]
    draw.polygon(valley, fill="#c7d6ac")
    river = [(110, 159), (150, 196), (186, 235), (239, 273),
             (290, 312), (349, 345), (409, 400), (489, 480)]
    draw.line(river, fill="#ecf7ed", width=24)
    draw.line(river, fill="#64aec5", width=14)
    draw.line(river, fill="#a9d9de", width=4)
    draw.ellipse((478, 69, 613, 192), fill="#c2d99b", outline="#739b59", width=3)
    draw.ellipse((494, 85, 597, 176), outline="#96b871", width=2)
    route = [(354, 337), (405, 312), (440, 271), (470, 226), (513, 192), (544, 132)]
    draw.line(route, fill="#9b8866", width=13)
    draw.line(route, fill="#f0e5b8", width=9)
    draw.line([(292, 359), (350, 337), (397, 353)], fill="#b4a07b", width=7)
    for x, y in ((311, 310), (348, 299), (374, 330), (319, 348), (352, 370), (281, 337)):
        draw.rectangle((x, y, x+22, y+19), fill="#fff0cd", outline="#75604d", width=1)
        draw.polygon([(x-3, y), (x+11, y-12), (x+25, y)], fill="#b96749")
        draw.rectangle((x+9, y+9, x+14, y+19), fill="#806855")
    # Safe-point marker stays recognizable in the base image (M1 ignores T).
    draw.ellipse((534, 122, 554, 142), fill="#e8f4c2", outline="#386847", width=2)
    draw.line((539, 132, 549, 132), fill="#386847", width=2)
    draw.line((544, 127, 544, 137), fill="#386847", width=2)
    draw.rounded_rectangle((12, 12, 390, 43), radius=5, fill="#f4f6e8")
    draw.text((23, 17), "DEMO VILLAGE | FICTIONAL TRAINING MAP", font=small, fill="#233f38")
    for xy, text in (((55, 276), "SLOPE"), ((211, 376), "RIVER"),
                     ((293, 401), "VILLAGE"), ((478, 52), "HIGH GROUND"), ((459, 202), "ESCAPE ROAD")):
        draw.text(xy, text, font=font, fill="#294b40", stroke_width=1, stroke_fill="#ecf2d9")
    draw.polygon([(601, 288), (595, 308), (607, 308)], fill="#294b40")
    draw.text((596, 266), "N", font=font, fill="#294b40")
    draw.rounded_rectangle((12, 433, 346, 466), radius=5, fill="#f4f6e8")
    draw.text((22, 441), "Not a real map or an evacuation forecast", font=small, fill="#294b40")
    image.save(folder / "village.png")
    # Rainfall is a hand-drawn-style grayscale gradient clipped by a separate mask.
    yy, xx = np.indices((480, 640))
    gray = np.clip((xx-50)*255//290, 0, 255).astype(np.uint8)
    Image.fromarray(gray).save(folder / "rainfall.png")
    mask = Image.new("L", (640, 480), 0)
    ImageDraw.Draw(mask).polygon([(42, 65), (194, 49), (340, 93), (285, 221), (100, 224)], fill=255)
    mask.save(folder / "rainfall_mask.png")
    mask = Image.new("L", (640, 480), 0)
    ImageDraw.Draw(mask).polygon(valley, fill=255)
    mask.save(folder / "flood_mask.png")
    print(f"PASS: four fictional map input PNGs written to {folder}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).parent)
    make_inputs(parser.parse_args().output)
