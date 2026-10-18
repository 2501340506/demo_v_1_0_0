"""Real sparse FAT32 images and independent directory expectations. No card writes."""
from pathlib import Path
import importlib.util
import json
import struct
import sys

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('lfn',HERE/'lfn_vectors.py')
lfn=importlib.util.module_from_spec(spec);spec.loader.exec_module(lfn)
OUT=Path(sys.argv[1]);OUT.mkdir(parents=True,exist_ok=True)
def put16(b,o,v):struct.pack_into('<H',b,o,v)
def put32(b,o,v):struct.pack_into('<I',b,o,v)
def file_entry(n):
 b=bytearray(32);b[:11]=f'PIC{n}    BMP'.encode();b[11]=32;put16(b,26,100+n);put32(b,28,1228854);return bytes(b)
cases=[]
for case in range(19):
 sectors={}
 def sector(lba):return sectors.setdefault(lba,bytearray(512))
 def fat(c,n):put32(sector(32+c//128),(c%128)*4,n)
 boot=sector(0);boot[0]=0xeb;put16(boot,11,512);boot[13]=1;put16(boot,14,32);boot[16]=1
 put32(boot,32,32+1024+65536);put32(boot,36,1024);put32(boot,44,5);boot[510:]=b'\x55\xaa'
 # The LFN chain starts in the last entry of one cluster and continues in
 # another, non-contiguous cluster, separated by a FAT read.
 def directory(chain,items):
  data=b''.join(items)+bytes(32)
  for i,c in enumerate(chain):
   sector(1056+c-2)[:]=data[i*512:(i+1)*512].ljust(512,b'\0');fat(c,chain[i+1] if i+1<len(chain) else 0x0fffffff)
 filler=[bytes([0xe5])+bytes(31)]*15
 parents=[lfn.entries('情景模式',b'WHATEV~1   ',20),lfn.entries('宣讲模式',b'NOTNAM~7   ',40)]
 root_second={16:65536,17:65537,18:65535}.get(case,11)
 directory([5,root_second],filler+[e for name in parents for e in name])
 if 8<=case<=15:
  # Exercise actual FAT bytes at range, loop and EOC boundaries. Upper four
  # reserved bits must still be masked before the two-cycle comparison.
  fat(5,[0,1,5,65538,131072,0x0ffffff7,0x0ffffff8,0xffffffff][case-8])
 children=[]
 order=[5,2,4,3] if case%2==0 else [3,4,2,5]
 for k in order:
  children.extend(lfn.entries(lfn.NAMES[k],f'R{k}NAME~8   '.encode(),50+k))
 directory([20,35],filler+children)
 for k in range(2,6):directory([50+k],[file_entry(n) for n in (4,1,3,2)])
 directory([40],[bytes([0xe5])+bytes(31)])
 requested=[0,20,54,40,1,70000,20,0][case] if case<8 else 0
 valid=[3,60,0,0,0,0,60,3][case] if case<8 else (3 if case>=16 else 0)
 err=0x21 if case in (4,5) else 0x10 if case==6 else 0
 if 8<=case<=13:err=0x23 if case==10 else 0x24
 if err:valid=0
 clusters={0:20,1:40} if case in (0,7) or case>=16 else {k:50+k for k in range(2,6)} if case in (1,6) else {}
 base=OUT/f'case{case}'
 # Materialize a genuine mountable image; sparse file only occupies written sectors.
 with base.with_suffix('.img').open('wb') as f:
  f.truncate((32+1024+65536)*512)
  for lba,b in sorted(sectors.items()):f.seek(lba*512);f.write(b)
 lbas=sorted(sectors)
 def hexfile(suffix,values,width):base.with_name(base.name+'_'+suffix+'.hex').write_text(''.join(f'{x:0{width}x}\n' for x in values))
 hexfile('lba',lbas,8);hexfile('bytes',(b for lba in lbas for b in sectors[lba]),2)
 expected=[requested,valid,err,len(lbas),1056+35-2 if case==6 else 0xffffffff,*[clusters.get(k,0) for k in range(6)],15 if case==2 else 0]
 hexfile('meta',expected,8);cases.append(dict(case=case,directory=requested,valid=valid,error=err))
(OUT/'manifest.json').write_text(json.dumps(cases,indent=2))
