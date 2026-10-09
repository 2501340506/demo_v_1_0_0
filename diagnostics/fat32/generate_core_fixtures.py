"""Deterministic sparse FAT32 media, expected byte streams and read traces.

No physical disk access. All sectors not explicitly listed are test failures.
"""
from pathlib import Path
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv)>1 else ROOT / 'diagnostics/output/fat32_core/fixtures'


def u16(buf, off, value):
    struct.pack_into('<H', buf, off, value)


def u32(buf, off, value):
    struct.pack_into('<I', buf, off, value)


def bmp(seed):
    width, height, stride = 3, 91, 12
    data = bytearray(54 + stride * height)
    data[:2] = b'BM'
    for off, value in ((2, len(data)), (10, 54), (14, 40), (18, width), (22, height)):
        u32(data, off, value)
    u16(data, 26, 1)
    u16(data, 28, 24)
    for row in range(height):
        for col in range(width):
            start = 54 + row * stride + col * 3
            data[start:start + 3] = bytes(((seed + row) % 256, col + 17, (row * 3 + seed) % 256))
        data[54 + row * stride + 9:54 + (row + 1) * stride] = b'\xad\xde\xef'
    return data


def entry(number, cluster, size, attr=0x20):
    b = bytearray(32)
    b[:11] = f'PIC{number}    BMP'.encode()
    b[11] = attr
    u16(b, 20, cluster >> 16)
    u16(b, 26, cluster & 65535)
    u32(b, 28, size)
    return b


CASES = [
    ('super_fragmented', {}),
    ('mbr_first_large_lba', {'slot': 0, 'partition': 200000}),
    ('mbr_second_jump_opcode', {'slot': 1, 'partition': 2048}),
    ('mbr_third', {'slot': 2, 'partition': 2048}),
    ('mbr_fourth_active_fat', {'slot': 3, 'partition': 2048, 'active': 1}),
    ('root_multisector_multicluster', {'spc': 2, 'long_dir': True}),
    ('missing_readonly_and_attributes', {'missing': True}),
    ('empty_directory', {'empty': True}),
    ('directory_eoc', {'dir_eoc': True}),
    *[(f'spc_{spc}', {'spc': spc}) for spc in (2, 4, 8, 16, 32, 64, 128)],
    ('bad_signature', {'bad_sig': True}),
    ('unsupported_bpb', {'bad_bpb': True}),
    ('bad_active_fat', {'bad_active': True}),
    ('boot_io_failure', {'boot_fail': True}),
    ('directory_io_failure', {'dir_fail': True}),
    ('file_early_eoc', {'chain_error': 'eoc'}),
    ('file_free_cluster', {'chain_error': 'free'}),
    ('file_self_loop', {'chain_error': 'self'}),
    ('file_long_loop_limit', {'chain_error': 'loop'}),
    ('file_data_io_failure', {'file_fail': True}),
    ('file_fat_io_failure', {'fat_fail': True}),
    ('true_directory_size_truncation', {'truncate': True}),
    ('file_size_zero', {'zero': True}),
    ('file_first_cluster_invalid', {'bad_first': True}),
    ('root_self_loop', {'root_error': 'self'}),
    ('root_long_loop_limit', {'root_error': 'loop'}),
    ('root_cluster_range', {'root_error': 'range'}),
    ('root_fat_io_failure', {'root_error': 'io'}),
    ('final_sector_io_failure', {'last_fail': True}),
    ('size_ignores_extra_allocated_cluster', {'extra_chain': True}),
    ('first_matching_partition_selected', {'slot': 1, 'partition': 4096, 'extra_partition': True}),
    ('contiguous_file', {'contiguous': True}),
    ('rescan_clears_results', {'empty': True, 'rescan': True}),
    ('single_fat', {'fat_count': 1}),
    ('exact_sector_eof', {'tail': 1536}),
    ('exact_cluster_eof', {'spc': 2, 'tail': 2048}),
]


def generate(name, cfg):
    spc = cfg.get('spc', 1)
    part = cfg.get('partition', 0)
    fat_sectors = 1024
    fat_count = cfg.get('fat_count', 2)
    reserved = 32
    count = 65536  # Real FAT32 cluster count, despite the sparse backing model.
    fat0 = part + reserved
    fat = fat0 + cfg.get('active', 0) * fat_sectors
    data_lba = fat0 + fat_count * fat_sectors
    media = {}
    scan_trace = [0]
    if part:
        scan_trace.append(part)
    scan_error = 0
    fail_lba, fail_byte = 0xffffffff, 0

    def sector(lba):
        return media.setdefault(lba, bytearray(512))

    def cluster_lba(cluster):
        return data_lba + (cluster - 2) * spc

    def set_fat(cluster, value):
        u32(sector(fat + cluster // 128), (cluster % 128) * 4, value)

    boot = sector(part)
    boot[0] = 0xeb
    u16(boot, 11, 512)
    boot[13] = spc
    u16(boot, 14, reserved)
    boot[16] = fat_count
    u32(boot, 32, reserved + fat_count * fat_sectors + spc * count)
    u32(boot, 36, fat_sectors)
    u16(boot, 40, 0x81 if cfg.get('active') else 0)
    u32(boot, 44, 5)  # Root deliberately is not cluster 2.
    boot[510:512] = b'\x55\xaa'
    if part:
        mbr = sector(0)
        mbr[0] = 0xeb  # Common MBR boot code must not be mistaken for a BPB.
        slot = cfg['slot']
        mbr[450 + 16 * slot] = 0x0c
        u32(mbr, 454 + 16 * slot, part)
        if cfg.get('extra_partition'):
            mbr[450 + 16 * (slot + 1)] = 0x0b
            u32(mbr, 454 + 16 * (slot + 1), part + 10000)
        mbr[510:512] = b'\x55\xaa'

    payloads = [bmp(i * 29 + 1) for i in range(4)]
    if cfg.get('tail'):
        for payload in payloads:
            payload.extend(bytes([0xbe]) * (cfg['tail'] - len(payload)))
            u32(payload, 2, len(payload))
    chains = [[130 + i * 10, 9 + i * 10, 800 + i * 10] for i in range(4)]
    if cfg.get('contiguous'):
        chains = [[130+i*10,131+i*10,132+i*10] for i in range(4)]
    sizes = [len(p) for p in payloads]
    if cfg.get('truncate'):
        sizes[0] = 600  # BMP header still claims the original complete length.
    if cfg.get('zero'):
        sizes[0] = 0
    for i, chain in enumerate(chains):
        for n, cluster in enumerate(chain):
            set_fat(cluster, chain[n+1] if n+1 < len(chain) else 0x0fffffff)
            for sec in range(spc):
                offset = (n * spc + sec) * 512
                if offset >= len(payloads[i]):
                    break
                block = sector(cluster_lba(cluster) + sec)
                block[:] = bytes([0xcc]) * 512
                piece = payloads[i][offset:offset+512]
                block[:len(piece)] = piece
    if cfg.get('extra_chain'):
        set_fat(chains[0][-1], 1000)  # Must not read this FAT entry or cluster.

    resources = [chain[0] for chain in chains]
    if cfg.get('bad_first'):
        resources[0] = 1
    mask = 15
    directory = [entry(i+1, resources[i], sizes[i]) for i in range(4)]
    if cfg.get('missing'):
        mask = 5
        deleted = entry(2, 0x1234, 100);deleted[0] = 0xe5
        directory = [deleted, entry(2, 99, 100, 0x0f), entry(2, 99, 100, 0x10),
                     entry(4, 99, 100, 0x08), entry(1, resources[0], sizes[0], 0x01),
                     entry(3, resources[2], sizes[2], 0x26)]
    if cfg.get('empty'):
        directory = [];mask = 0
    if cfg.get('long_dir'):
        # PIC1 in second sector, PIC2/3/4 in a fragmented later root cluster.
        deleted = bytes([0xe5]) + bytes(31)
        directory = [deleted]*16 + directory[:1] + [deleted]*15 + directory[1:]
    if cfg.get('dir_eoc') or cfg.get('root_error'):
        directory = [bytes([0xe5])+bytes(31)]*(16*spc)
        mask = 0
    root_chain = [5, 700, 5, 700]
    for i in range((len(directory)+16*spc-1)//(16*spc) or 1):
        cluster = root_chain[i]
        for sec in range(spc):
            block = sector(cluster_lba(cluster)+sec)
            for slot in range(16):
                idx = (i*spc+sec)*16+slot
                if idx<len(directory):
                    block[slot*32:(slot+1)*32] = directory[idx]
        set_fat(cluster, root_chain[i+1] if (i+1)*16*spc<len(directory) else 0x0fffffff)
    if cfg.get('root_error'):
        for sec in range(spc):
            sector(cluster_lba(700)+sec)[:] = (bytes([0xe5])+bytes(31))*16
        set_fat(5, {'self':5, 'loop':700, 'range':1, 'io':700}[cfg['root_error']])
        set_fat(700,5)
        if cfg['root_error']=='io':fail_lba=fat

    # Independent directory walk computes expected requests and stop condition.
    root = 5
    for visited in range(1,5):
        ended = False
        found = 0 if visited==1 else found
        for sec in range(spc):
            lba = cluster_lba(root)+sec
            scan_trace.append(lba)
            block = sector(lba)
            for idx in range(0,512,32):
                if block[idx]==0:
                    ended=True;break
                label = bytes(block[idx:idx+11])
                if block[idx+11] & 0x18 == 0 and label in [f'PIC{x}    BMP'.encode() for x in range(1,5)]:
                    found |= 1 << (block[idx+3]-ord('1'))
            if ended or found==15:break
        if ended or found==15:break
        scan_trace.append(fat+root//128)
        nxt = struct.unpack_from('<I',sector(fat+root//128),(root%128)*4)[0] & 0x0fffffff
        if cfg.get('root_error')=='io':scan_error=0x10;break
        if nxt>=0x0ffffff8:break
        if nxt<2 or nxt>count+1:scan_error=0x24;break
        if nxt==root:scan_error=0x23;break
        if visited==4:scan_error=0x26;break
        root=nxt
    if cfg.get('bad_sig'):
        sector(0)[510]=0;scan_trace=[0];scan_error=0x20
    if cfg.get('bad_bpb'):
        u16(boot,11,1024);scan_trace=[0];scan_error=0x21
    if cfg.get('bad_active'):
        u16(boot,40,0x82);scan_trace=[0];scan_error=0x21
    if cfg.get('boot_fail'):
        fail_lba=0;scan_trace=[0];scan_error=0x10
    if cfg.get('dir_fail'):
        fail_lba=cluster_lba(5);scan_trace=scan_trace[:2];scan_error=0x10;mask=0
    if scan_error:
        mask=0

    if cfg.get('chain_error'):
        kind=cfg['chain_error']
        set_fat(chains[0][0], {'eoc':0xfffffff,'free':0,'self':chains[0][0],'loop':chains[0][1]}[kind])
        if kind=='loop':
            sizes[0]=4000
            set_fat(chains[0][1],chains[0][0])
            u32(sector(cluster_lba(5)),28,sizes[0])
    if cfg.get('file_fail'):fail_lba=cluster_lba(chains[0][1])
    if cfg.get('fat_fail'):fail_lba=fat+chains[0][0]//128
    if cfg.get('last_fail'):
        fail_lba=cluster_lba(chains[0][-1]);fail_byte=512

    trace = list(scan_trace)
    expected = bytearray()
    errors, lengths, decode_errors = [0]*4,[0]*4,[0]*4
    if not scan_error:
        for i in range(4):
            if not (mask>>i)&1:continue
            remain=sizes[i];cluster=resources[i];visits=1
            if remain==0:
                decode_errors[i]=3
                continue
            if cluster<2 or cluster>count+1:
                errors[i]=0x24;decode_errors[i]=2;continue
            while remain:
                for sec in range(spc):
                    lba=cluster_lba(cluster)+sec;trace.append(lba)
                    if lba==fail_lba and fail_byte==0:
                        errors[i]=0x10;break
                    piece=sector(lba)[:min(512,remain)]
                    expected.extend(piece);lengths[i]+=len(piece);remain-=len(piece)
                    if lba==fail_lba:
                        errors[i]=0x10;break
                    if not remain:break
                if errors[i] or not remain:break
                lba=fat+cluster//128;trace.append(lba)
                if lba==fail_lba:errors[i]=0x10;break
                nxt=struct.unpack_from('<I',sector(lba),(cluster%128)*4)[0]&0x0fffffff
                if nxt>=0x0ffffff8:errors[i]=0x25;break
                if nxt<2 or nxt>count+1:errors[i]=0x24;break
                if visits>=4:errors[i]=0x26;break
                if nxt==cluster:errors[i]=0x23;break
                cluster=nxt;visits+=1
            decode_errors[i]=2 if errors[i] else (1 if cfg.get('truncate') and i==0 else 0)

    lbas = sorted(media)
    metadata=[scan_error,mask,part,spc,fat,data_lba,count+1,*resources,*sizes,fail_lba,
              fail_byte,*errors,*lengths,len(lbas),len(trace),*decode_errors,int(cfg.get('rescan',False))]
    return media,lbas,metadata,trace,expected or bytes([0]),decode_errors


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    manifest=[]
    for idx,(name,cfg) in enumerate(CASES):
        media,lbas,meta,trace,expected,_=generate(name,cfg)
        def write(suffix,values,width):
            (OUT/f'case{idx}_{suffix}.hex').write_text(''.join(f'{v:0{width}x}\n' for v in values),encoding='ascii')
        write('lba',lbas,8);write('meta',meta,8);write('trace',trace,8)
        write('bytes',(b for lba in lbas for b in media[lba]),2)
        write('expected',expected,2)
        manifest.append({'id':idx,'name':name,'options':cfg,'sectors':len(lbas),
                         'expected_scan_error':meta[0],'expected_mask':meta[1],
                         'expected_file_errors':meta[17:21],'expected_read_requests':len(trace)})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(f'Generated {len(CASES)} sparse FAT32 cases in {OUT}')


if __name__=='__main__':main()
