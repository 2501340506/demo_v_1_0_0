"""Decode TD mapped BRAM INIT/INITP bits and compare every valid font row."""
import argparse
import json
import re
from pathlib import Path


def check(netlist,reference,out):
    text=netlist.read_text(encoding='utf-8')
    pattern=r'// address_offset=([^\n]+)\n\s*// g_scene_text\$g_narration\$overlay/font/ramread0_syn_4_8192x16\n\s*EG_PHY_BRAM #\((.*?)\n\s*\\g_scene_text[^\n]+\('
    blocks=re.findall(pattern,text,re.S)
    assert len(blocks)==15,len(blocks)
    restored=[0]*8192;coverage=[0]*8192
    for info,params in blocks:
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
    assert len(expected)==4416
    for address,value in enumerate(expected):
        assert coverage[address]==65535 and restored[address]==value,(address,hex(restored[address]),hex(value))
    report=dict(netlist=str(netlist),method='decode mapped EG_PHY_BRAM INIT/INITP, compare all 16 bits per row',
                bram_instances=len(blocks),glyphs=276,rows_compared=len(expected),passed=True)
    out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS mapped font:',len(blocks),'BRAMs;',len(expected),'rows byte/bit exact')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--netlist',required=True,type=Path);p.add_argument('--reference',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path);a=p.parse_args()
    check(a.netlist,a.reference,a.out)
