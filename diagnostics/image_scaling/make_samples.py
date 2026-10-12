"""Board BMPs plus exact floor-mapped reference images; no card writes."""
from pathlib import Path
import argparse,zipfile
import numpy as np
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=False)
sizes=[(160,120),(801,601),(1920,1080),(1080,1920)]
for i,(w,h) in enumerate(sizes,1):
    image=Image.new('RGB',(w,h));d=ImageDraw.Draw(image)
    colors=['#d23f31','#e9ad34','#3baf65','#3295ca','#7446af','#e5e5e5']
    for k,c in enumerate(colors):d.rectangle((k*w//6,0,(k+1)*w//6-1,h-1),fill=c)
    step=max(12,min(w,h)//8)
    for x in range(0,w,step):d.line((x,0,x,h-1),fill='#333333',width=max(1,w//640))
    for y in range(0,h,step):d.line((0,y,w-1,y),fill='#333333',width=max(1,w//640))
    r=min(w,h)//3
    d.ellipse((w//2-r,h//2-r,w//2+r,h//2+r),outline='white',width=max(2,w//160))
    d.rectangle((0,0,w-1,h-1),outline='white',width=max(1,w//320))
    d.rectangle((4,4,min(w-5,180),32),fill='black');d.text((7,8),f'PIC{i} {w} x {h} TOP',fill='white')
    d.rectangle((0,h-8,w//4,h-1),fill='black')
    image.save(a.output/f'PIC{i}.BMP')
    if w*480>=h*640:dw,dh=640,max(1,h*640//w)
    else:dw,dh=max(1,w*480//h),480
    canvas=np.zeros((480,640,3),dtype=np.uint8)
    scaled=np.asarray(image)[(np.arange(dh)*h//dh)[:,None],(np.arange(dw)*w//dw)[None,:]]
    l,t=(640-dw)//2,(480-dh)//2;canvas[t:t+dh,l:l+dw]=scaled
    Image.fromarray(canvas).save(a.output/f'PIC{i}_expected.png')
with zipfile.ZipFile(a.output/'board_samples.zip','w',zipfile.ZIP_DEFLATED) as z:
    for f in a.output.glob('PIC*'):z.write(f,f.name)
print('Created four positive-height 24-bit BMPs and exact 640x480 references:',a.output)
