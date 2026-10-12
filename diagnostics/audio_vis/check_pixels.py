"""Check RTL-rendered frames against independent capsule geometry, save previews."""
from pathlib import Path
import math
import colorsys
import sys
from PIL import Image

def expected(x, y, mode):
    dx, dy = x-520, y-310
    if 52 <= math.hypot(dx, dy) < 64:
        return 0
    angle = math.atan2(dy, dx) % (2*math.pi)
    b = int(math.floor(angle * 96 / (2*math.pi)+0.5)) % 96
    theta = b*2*math.pi/96
    along = dx*math.cos(theta)+dy*math.sin(theta)
    across = -dx*math.sin(theta)+dy*math.cos(theta)
    h = [0,7,28,b%29][mode]
    if math.hypot(across, max(65.5-along, along-(65.5+h),0)) <= 1.5+1e-9:
        hue=(b//16+(b%16)*12/191)/6
        red,green,blue=(round(c*255) for c in colorsys.hsv_to_rgb(hue,191/255,1))
        return (red<<16)|(green<<8)|blue
    return ((x%256)<<16)|((y%256)<<8)|0x60

def main():
    folder=Path(sys.argv[1])
    for mode in range(4):
        pixels=[int(line,16) for line in (folder/f'ring_{mode}.hex').read_text().splitlines()]
        assert len(pixels)==640*480,len(pixels)
        for i,p in enumerate(pixels):
            x,y=i%640,i//640
            e=expected(x,y,mode)
            assert p==e,(mode,x,y,hex(p),hex(e))
        im=Image.frombytes('RGB',(640,480),b''.join(p.to_bytes(3,'big') for p in pixels))
        im.save(folder/f'ring_{mode}.png')
    print('PASS independent capsule reference: 1,228,800 RTL pixels; silence/weak/strong/varying heights')

if __name__=='__main__':main()
