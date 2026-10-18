"""VFAT fixtures shared by stream tests and the later FAT32 card images."""
from pathlib import Path
import random
import struct
import sys

NAMES = ['情景模式', '宣讲模式', 'landslide_village', 'debris_village', 'flood_village', 'quake_village']
OFFSETS = [1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30]


def checksum(alias):
    n = 0
    for c in alias:
        n = (((n & 1) << 7) + (n >> 1) + c) & 255
    return n


def entries(name, alias, cluster, attr=0x10):
    assert len(alias) == 11
    chars = list(struct.unpack('<' + 'H' * (len(name.encode('utf-16le')) // 2), name.encode('utf-16le')))
    count = (len(chars) + 12) // 13
    chars += [0] + [0xffff] * 13
    result = []
    for seq in range(count, 0, -1):
        e = bytearray(32)
        e[0], e[11], e[13] = seq | (0x40 if seq == count else 0), 0x0f, checksum(alias)
        for off, char in zip(OFFSETS, chars[(seq - 1) * 13:seq * 13]):
            struct.pack_into('<H', e, off, char)
        result.append(e)
    e = bytearray(32)
    e[:11], e[11] = alias, attr
    struct.pack_into('<H', e, 20, cluster >> 16)
    struct.pack_into('<H', e, 26, cluster & 0xffff)
    result.append(e)
    return result


def vectors(out):
    out.mkdir(parents=True, exist_ok=True)
    fixture, expected = [], []
    rng = random.Random(6018)

    def add(seq, mask=0, cluster=0):
        for i, entry in enumerate(seq):
            fixture.extend(entry)
            expected.append(((mask << 32) | cluster) if i == len(seq) - 1 else 0)

    # Arbitrary aliases and directory ordering, repeated with varying clusters.
    for cycle in range(30):
        order = list(range(6))
        rng.shuffle(order)
        for index in order:
            cluster = rng.randrange(2, 0x0fffffff)
            alias = f'X{cycle:03}{index:02}~1'.encode() + b'   '
            valid = entries(NAMES[index], alias, cluster)
            add(valid, 1 << index, cluster)
            # Checksum mismatch; deleted SFN; a file instead of a directory.
            for offset, value in [(13, valid[0][13] ^ 1), (12, 1), (26, 2), (0, valid[0][0] | 0x80)]:
                bad = [bytearray(e) for e in valid]
                bad[0][offset] = value
                add(bad)
            bad = [bytearray(e) for e in valid]
            bad[-1][0] = 0xe5
            add(bad)
            add(entries(NAMES[index], alias, cluster, 0x20))
            # Reject prefix/suffix/case confusion and broken LFN order.
            for changed in [NAMES[index] + 'x', 'x' + NAMES[index], NAMES[index][:-1], NAMES[index].upper()]:
                if changed != NAMES[index]:
                    add(entries(changed, alias, cluster))
            if len(valid) > 2:
                add([valid[1], valid[0], valid[-1]])
                add([valid[0], valid[-1]])
            # Chain must be consumed by the immediately associated SFN.
            add([valid[-1]])
    (out / 'lfn_bytes.hex').write_text(''.join(f'{x:02x}\n' for x in fixture))
    (out / 'lfn_expected.hex').write_text(''.join(f'{x:010x}\n' for x in expected))
    (out / 'lfn_count.txt').write_text(str(len(expected)))
    print(f'{len(expected)} directory entries, {len(fixture)} streamed bytes')


if __name__ == '__main__':
    vectors(Path(sys.argv[1]))
