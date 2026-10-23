"""Decode TD mapped BRAM INIT/INITP bits and compare every valid font row."""
import argparse
import json
import re
from pathlib import Path


def check(netlist,reference,out):
    text=netlist.read_text(encoding='utf-8')
    pattern=r'// address_offset=([^\n]+)\n\s*// g_scene_text\$g_narration\$overlay/font/ramread0_syn_\d+_(\d+)x(\d+)\n\s*EG_PHY_BRAM #\((.*?)\n\s*\\g_scene_text[^\n]+\('
    blocks=re.findall(pattern,text,re.S)
    assert blocks,'No mapped narration ROM found'
    shapes={(int(depth),int(width)) for _,depth,width,_ in blocks}
    assert len(shapes)==1,shapes
    rom_depth,rom_width=shapes.pop()
    assert rom_width in (16,21) and rom_depth==8192,(rom_depth,rom_width)
    restored=[0]*rom_depth;coverage=[0]*rom_depth
    for info,_,_,params in blocks:
        config=dict(re.findall(r'(\w+)=(\d+)','address_offset='+info))
        start=int(config['address_offset']);bit=int(config['data_offset'])
        width=int(config['width']);depth=int(config['depth'])
        values={key:int(value,16 if radix=='h' else 2) for key,radix,value in re.findall(r'\.(INIT(?:P)?_[0-9A-F]{2})\(256\x27([hb])([0-9a-fA-F]+)\)',params)}
        data=sum(values.get(f'INIT_{i:02X}',0)<<(256*i) for i in range(32))
        parity=sum(values.get(f'INITP_{i:02X}',0)<<(256*i) for i in range(4))
        assert width in (1,9)
        for address in range(depth):
            value=((data>>(address*8))&255)|(((parity>>address)&1)<<8) if width==9 else (data>>address)&1
            mask=((1<<width)-1)<<bit
            assert not coverage[start+address]&mask
            restored[start+address]|=value<<bit;coverage[start+address]|=mask
    expected=[int(row,16) for row in reference.read_text(encoding='ascii').splitlines()]
    assert expected and len(expected)%rom_width==0
    glyphs=len(expected)//rom_width
    for address,value in enumerate(expected):
        assert coverage[address]==(1<<rom_width)-1 and restored[address]==value,(address,hex(restored[address]),hex(value))
    report=dict(netlist=str(netlist),method=f'decode mapped EG_PHY_BRAM INIT/INITP, compare all {rom_width} bits per row',
                bram_instances=len(blocks),glyphs=glyphs,font_size=rom_width,rows_compared=len(expected),passed=True)
    out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS mapped font:',len(blocks),'BRAMs;',len(expected),'rows byte/bit exact')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--netlist',required=True,type=Path);p.add_argument('--reference',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path);a=p.parse_args()
    check(a.netlist,a.reference,a.out)
