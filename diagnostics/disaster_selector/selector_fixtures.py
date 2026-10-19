"""Sparse FAT32 cards for production reader/controller tests. Never opens G:."""
from pathlib import Path
import importlib.util
import struct
import sys

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('lfn', HERE/'lfn_vectors.py')
lfn=importlib.util.module_from_spec(spec);spec.loader.exec_module(lfn)
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)

def u16(b,o,v):struct.pack_into('<H',b,o,v)
def u32(b,o,v):struct.pack_into('<I',b,o,v)

for case in range(24):
    sectors={}
    def sec(lba):return sectors.setdefault(lba,bytearray(512))
    spc=64 if case in (22,23) else 1
    def cluster_lba(c):return 1056+(c-2)*spc
    def fat(c,n):u32(sec(32+c//128),c%128*4,n)
    boot=sec(0);boot[:3]=b'\xeb\x58\x90';u16(boot,11,512);boot[13]=spc
    u16(boot,14,32);boot[16]=1;u32(boot,32,1056+65536*spc);u32(boot,36,1024)
    u32(boot,44,5);boot[510:512]=b'\x55\xaa'
    def directory(chain,entries):
        data=b''.join(entries)+bytes(32)
        for i in range((len(data)+511)//512):
            sec(cluster_lba(chain[i//spc])+i%spc)[:]=data[i*512:(i+1)*512].ljust(512,b'\0')
        for i,c in enumerate(chain):
            fat(c,chain[i+1] if i+1<len(chain) else 0x0fffffff)
    def entry(name,c,size):
        b=bytearray(32);b[:11]=name;b[11]=32;u16(b,26,c);u32(b,28,size);return b
    def bmp(c,hazard,stage,bad=False,decode_bad=False):
        b=sec(cluster_lba(c));b[:2]=b'BM';u32(b,2,78);b[6]=hazard;b[7]=stage
        u32(b,10,54);u32(b,14,40);u32(b,18,2);u32(b,22,3)
        u16(b,26,1);u16(b,28,24)
        # 2x3 aspect gives letterbox x=160..479 after scaling.
        for y in range(3):
            for x in range(2):b[54+y*8+x*3:57+y*8+x*3]=bytes([0x80+x,hazard*32,stage*40])
        if bad:b[6]=4 if hazard!=4 else 1
        if decode_bad:
            # Header passes, streamer fails following cluster after byte 511.
            u32(b,2,590);u32(b,22,67);fat(c,0x0ffffff7)
        else:fat(c,0x0fffffff)
        if case in (20,23) and (hazard==0 or hazard==1):
            size=54+640*480*(4 if hazard else 3)
            payload=bytearray(size);payload[:54]=b[:54]
            u32(payload,2,size);u32(payload,18,640);u32(payload,22,480);u16(payload,28,32 if hazard else 24)
            payload[54:]=bytes((128,hazard*32,stage*40,255) if hazard else (128,0,stage*40))*307200
            for i in range((size+511)//512):
                ci=i//spc
                sec(cluster_lba(c+ci)+i%spc)[:]=payload[i*512:(i+1)*512].ljust(512,b'\0')
                fat(c+ci,c+ci+1 if (ci+1)*spc*512<size else 0x0fffffff)
            return size
        return 590 if decode_bad else 78
    roots=[]
    if case!=5:
        roots+=lfn.entries(lfn.NAMES[0],b'ODDXYZ~8   ',20)
        roots+=lfn.entries(lfn.NAMES[1],b'PUBANY~3   ',40)
    children=[]
    for k in (5,2,4,3):children+=lfn.entries(lfn.NAMES[k],f'XYZ{k}ZZ~2   '.encode(),50+k)
    filler=[bytes([0xe5])+bytes(31)]*15
    directory([20,35],filler+children)
    expected=15
    for h in range(1,5):
        entries=[]
        for stage in (4,1,3,2):
            c=100+h*8+stage
            if case in (20,23) and h==1:c=10000+stage*2500
            if (case==2 and h==2 or case==13 and h==1) and stage==3:continue
            bad=case==2 and h==3 and stage==2
            decode_bad=(case==3 and h==2 and stage==3) or (case==14 and h==1 and stage==1)
            size=bmp(c,h,stage,bad,decode_bad)
            if h==2 and stage==3 and case in (7,8,9):
                if case==7:sec(1054+c)[7]=2  # stage name/header role mismatch
                if case==8:sec(1054+c)[:2]=b'XX'  # corrupt BMP header
                # case 9 injects transport failure in the controller bench.
            entries.append(entry(f'PIC{stage}    BMP'.encode(),c,size))
        if case>=11 and not(case==12 and h==1):
            c=1000+h*320
            data=bytearray(147510);data[:2]=b'BM';u32(data,2,len(data));u32(data,10,54);u32(data,14,40)
            u32(data,18,256);u32(data,22,192);u16(data,26,1);u16(data,28,24)
            for y in range(192):
                for x in range(256):
                    p=54+(y*256+x)*3;data[p:p+3]=bytes((x&255,h*32,y&255))
            if case==12 and h==2:data[:2]=b'XX'
            if case==12 and h==3:u32(data,18,255)
            for i in range((len(data)+511)//512):
                ci=i//spc
                sec(cluster_lba(c+ci)+i%spc)[:]=data[i*512:(i+1)*512].ljust(512,b'\0')
                fat(c+ci,c+ci+1 if (ci+1)*spc<289 else 0x0fffffff)
            if case==12 and h==4:fat(c,0x0ffffff7)
            entries.append(entry(b'THUMB   BMP',c,len(data)))
        if case==10 and h==1:
            for name,c,payload in (
                (b'SND1    PCM',240,b'\x34\x12'*256),
                (b'FONT    BIN',241,bytes(i&255 for i in range(416))),
                (b'TEXT    BIN',242,bytes(i&255 for i in range(44)))):
                sec(1054+c)[:len(payload)]=payload;fat(c,0x0fffffff)
                entries.append(entry(name,c,len(payload)))
        directory([51+h],entries)
    pubs=[]
    for stage in (2,4,1,3):
        c=30000+stage*2000 if case in (20,23) else 180+stage
        size=bmp(c,0,0)
        if case in (19,20,21,22,23):
            if case in (20,23):
                size=bmp(c,0,stage)
                sec(cluster_lba(c))[7]=0  # publicity header tags remain zero
            for y in range(3):
                for x in range(2):sec(cluster_lba(c))[54+y*8+x*3+2]=stage*40
        if not(case==4 and stage==2):pubs.append(entry(f'EDU{stage}    BMP'.encode(),c,size))
    directory([40],pubs)
    if case in (16,19,20,21,22,23):
        for name,c,payload in ((b'FONT    BIN',245,bytes(416)),(b'TEXT    BIN',246,bytes(44)),
                               (b'VOI1    PCM',247,b'\x34\x12'*256)):
            sec(cluster_lba(c))[:len(payload)]=payload;fat(c,0x0fffffff)
            pubs.append(entry(name,c,len(payload)))
        directory([40],pubs)
    if case in (19,20,21,22,23):
        for stage in (2,3,4):
            c=247+stage
            sec(cluster_lba(c))[:]=b'\x34\x12'*256;fat(c,0x0fffffff)
            pubs.append(entry(f'VOI{stage}    PCM'.encode(),c,512))
        directory([40],pubs)
    if case in (21,23):
        # Long narration stays active during background frame loading and fade.
        pubs=[e for e in pubs if e[:3]!=b'VOI']
        for stage in range(1,5):
            c=4000+stage*300
            for i in range(188):
                ci=i//spc
                sec(cluster_lba(c+ci)+i%spc)[:]=b'\x34\x12'*256
                fat(c+ci,c+ci+1 if (ci+1)*spc<188 else 0x0fffffff)
            pubs.append(entry(f'VOI{stage}    PCM'.encode(),c,188*512))
        directory([40],pubs)
    if case in (1,4,5,6):
        for stage in (4,2,1,3):
            c=200+stage;size=bmp(c,0,0);roots.append(entry(f'PIC{stage}    BMP'.encode(),c,size))
            if case in (1,6):roots.append(entry(f'EDU{stage}    BMP'.encode(),c,size))
    if case==5:expected=0
    directory([5,11,18],filler+roots)
    base=out/f'selector{case}';lbas=sorted(sectors)
    with base.with_suffix('.img').open('wb') as f:
        f.truncate((1056+65536*spc)*512)
        for lba in lbas:f.seek(lba*512);f.write(sectors[lba])
    for suffix,values,width in [('lba',lbas,8),('bytes',(v for lba in lbas for v in sectors[lba]),2),
                                ('meta',[len(lbas),expected,1 if case not in (4,5) else 0],8)]:
        base.with_name(base.name+'_'+suffix+'.hex').write_text(''.join(f'{v:0{width}x}\n' for v in values))
print('Prepared 24 sparse FAT32 selector cards (including full-size pages with sustained narration)')
