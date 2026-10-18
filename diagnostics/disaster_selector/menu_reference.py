"""Independent Pillow reference for the fixed Chinese menu, no card writes."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys

out=Path(sys.argv[1])
font=ImageFont.truetype('C:/Windows/Fonts/simsun.ttc',16)
labels=['滑坡','泥石流','山洪','地震']
with (out/'menu_reference.hex').open('w') as stream:
    for frame in range(5):
        focus=frame%4
        valid=15 if frame<4 else 9
        im=Image.new('RGB',(640,480),(16,24,32))
        px=im.load()
        for tile in range(4):
            ox=tile%2*320;oy=tile//2*240
            for y in range(192):
                for x in range(256):
                    px[ox+32+x,oy+8+y]=(40+tile*48,y+8,(x+32)&255) if valid>>tile&1 else (96,96,96)
        d=ImageDraw.Draw(im)
        d.rectangle((8,2,631,477),outline=(192,192,192))
        d.rectangle((319,2,320,477),fill=(192,192,192))
        d.rectangle((8,239,631,240),fill=(192,192,192))
        ox=focus%2*320;oy=focus//2*240
        d.rectangle((ox+28,oy+4,ox+291,oy+237),outline=(255,255,0),width=2)
        for tile,label in enumerate(labels):
            mask=Image.new('1',(len(label)*16,16))
            # Draw characters individually to keep exactly 16 pixels per glyph.
            for j,ch in enumerate(label):ImageDraw.Draw(mask).text((j*16,-1),ch,font=font,fill=1)
            mask=mask.resize((len(label)*32,32),Image.Resampling.NEAREST)
            ox=tile%2*320+(320-mask.width)//2;oy=tile//2*240+204
            im.paste((255,255,255) if valid>>tile&1 else (144,144,144),(ox,oy),mask)
        if frame in (0,4):im.save(out/f'menu_expected_{frame}.png')
        stream.writelines(f'{r:02x}{g:02x}{b:02x}\n' for r,g,b in im.getdata())
