from pathlib import Path
import sys, struct, math
from PIL import Image

root=Path(__file__).resolve().parents[2]
action=sys.argv[1];out=Path(sys.argv[2]).resolve()
if action=='prepare':
    # Local user music stays local. Fall back to a deterministic amplitude sweep.
    source=root/'tools/BGM.PCM'
    if source.exists():
        raw=source.read_bytes()
        # Use a segment after the start, avoiding a possible fade-in.
        offset=min(48000*2*10,max(0,len(raw)-96000))
        raw=raw[offset:offset+96000]
        values=list(struct.unpack('<'+'h'*(len(raw)//2),raw))
        values=(values*math.ceil(48000/len(values)))[:48000]
        description=f'Local BGM.PCM, byte offset {offset}, 48kHz signed 16-bit mono'
    else:
        values=[int((0.1+0.8*(i/48000))*16000*math.sin(i*2*math.pi*440/48000)) for i in range(48000)]
        description='Synthetic 440Hz amplitude sweep (local BGM.PCM unavailable)'
    (out/'music.hex').write_text(''.join(f'{v&65535:04x}\n' for v in values))
    (out/'SOURCE.txt').write_text(description,encoding='utf-8')
    print(description)
else:
    frames=[];tables=[]
    for n in range(20):
        values=[int(v,16) for v in (out/f'music_{n:2d}.hex').read_text().splitlines()]
        assert len(values)==640*480
        tables.append(tuple(map(int,(out/f'heights_{n:2d}.txt').read_text().splitlines())))
        frames.append(Image.frombytes('RGB',(640,480),b''.join(v.to_bytes(3,'big') for v in values)))
    assert len(set(tables))>3,'Music must change displayed heights'
    frames[0].save(out/'music.gif',save_all=True,append_images=frames[1:],duration=20,loop=0)
    frames[10].save(out/'music.png')
    print('PASS music preview: 20 RTL-rendered frames with changing heights')
