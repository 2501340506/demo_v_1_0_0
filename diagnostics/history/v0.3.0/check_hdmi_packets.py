"""Independent checks on packets reconstructed from the three TMDS outputs."""
from pathlib import Path
import sys


def ecc(data, count):
    # Polynomial long division, MSB-oriented dividend built from wire order.
    # G(x)=x^8+x^7+x^6+1; map remainder back to LSB-first wire bits.
    dividend = 0
    for bit in range(count):
        dividend = (dividend << 1) | ((data >> bit) & 1)
    dividend <<= 8
    for bit in range(count + 7, 7, -1):
        if dividend & (1 << bit):
            dividend ^= 0x1C1 << (bit - 8)
    return int(f'{dividend:08b}'[::-1], 2)


def check(path):
    samples = []
    sent = 0
    counts = {1: 0, 2: 0, 0x84: 0}
    finished = False
    for row in Path(path).read_text().splitlines():
        fields = row.split()
        if fields[0] == 'A':
            samples.append(tuple(int(v, 16) for v in fields[1:]))
        elif fields[0] == 'P':
            header, *blocks = [int(v, 16) for v in fields[1:]]
            assert header >> 24 == ecc(header & 0xFFFFFF, 24), ('header BCH', hex(header))
            for block in blocks:
                assert block >> 56 == ecc(block & ((1 << 56)-1), 56), ('body BCH', hex(block))
            body = [block & ((1 << 56)-1) for block in blocks]
            kind = header & 255
            counts[kind] += 1
            if kind == 2:
                assert header & 0xFFFFFF == (0x100F02 if sent % 192 == 0 else 0x000F02)
                for sub in body:
                    assert sent < len(samples), 'audio sent before input handshake'
                    left, right = samples[sent]
                    assert sub & 0xFFFFFF == left << 8, ('left order/alignment', sent)
                    assert (sub >> 24) & 0xFFFFFF == right << 8, ('right order/alignment', sent)
                    status = int(sent % 192 in (25, 33))
                    for channel, value in enumerate((left, right)):
                        nibble = (sub >> (48 + 4*channel)) & 15
                        assert nibble & 7 == status << 2, ('V/U/C', sent)
                        assert (value.bit_count() + status + (nibble >> 3)) % 2 == 0, ('parity', sent)
                    sent += 1
            elif kind == 1:
                assert header & 0xFFFFFF == 1
                # SB0 reserved, CTS high/mid/low in SB1..3, N in SB4..6.
                expected = int.from_bytes(bytes([0, 0, 0x61, 0xA8, 0, 0x18, 0]), 'little')
                assert body == [expected]*4, ('ACR N/CTS bytes', [hex(v) for v in body])
            else:
                assert kind == 0x84 and header & 0xFFFFFF == 0x0A0184
                payload = b''.join(v.to_bytes(7, 'little') for v in body)
                assert (0x84+1+10+sum(payload[:11])) % 256 == 0, 'InfoFrame checksum'
                assert payload == bytes([0x70, 1])+bytes(26), 'Audio InfoFrame stereo fields'
        else:
            assert fields[0] == 'END'
            assert int(fields[1]) == len(samples) == sent, ('untransmitted samples', len(samples), sent)
            assert int(fields[2]) == sum(counts.values())
            finished = True
    assert finished and sent >= 768 and counts[1] >= 20 and counts[0x84] >= 2
    print(f'PASS {Path(path).name}: {sent} samples, {sent//192} IEC blocks, packets {counts}; BCH, stereo order, 24-bit alignment, parity, N/CTS, InfoFrame')


def check_primitives(path):
    terc = [0x29C,0x263,0x2E4,0x2E2,0x171,0x11E,0x18E,0x13C,
            0x2CC,0x139,0x19C,0x2C6,0x28E,0x271,0x163,0x2C3]
    controls = [0x354,0x0AB,0x154,0x2AB]
    rd = 0
    vectors = 0
    failures = []
    for row in Path(path).read_text().splitlines():
        kind, *fields = row.split()
        values = [int(v,16) for v in fields]
        if kind == 'B':
            value,b3,b7 = values
            if b3 != ecc(value & 0xFFFFFF,24) or b7 != ecc(value,56):
                failures.append('BCH bit order')
        elif kind == 'R':
            sub = int.from_bytes(bytes([0,0,0x61,0xA8,0,0x18,0]),'little')
            if values[0] != sum(sub << (56*i) for i in range(4)):
                failures.append('ACR reserved/CTS/N byte positions')
        else:
            mode,video,island,control,*symbols = values
            if mode == 1:
                # Transition-minimized word from XOR prefix sums; choose
                # inversion using running symbol disparity, independently
                # computed from actual transmitted bit counts below.
                xnor = video.bit_count()>4 or (video.bit_count()==4 and video&1==0)
                bits = [video&1]
                for i in range(1,8):
                    bits.append(bits[-1] ^ ((video>>i)&1) ^ xnor)
                word = sum(int(v)<<i for i,v in enumerate(bits))
                q8 = int(not xnor)
                balance = 2*word.bit_count()-8
                invert = (not q8) if rd==0 or balance==0 else ((rd>0)==(balance>0))
                expected = (int(invert)<<9) | (q8<<8) | (word ^ (255 if invert else 0))
                assert symbols == [expected]*3, ('TMDS coding/disparity', video, rd)
                rd += 2*expected.bit_count()-10
                assert abs(rd)<=8
            else:
                rd=0
                if mode == 0: expected=[controls[control]]*3
                elif mode == 2: expected=[0x2CC,0x133,0x2CC]
                elif mode == 3: expected=[terc[island]]*3
                else: expected=[terc[12+control],0x133,0x133]
                assert symbols == expected, ('control/TERC4/guard', mode, symbols)
            vectors += 1
    assert not failures, sorted(set(failures))
    assert vectors == 1088
    print('PASS primitives: 256 BCH vectors at both lengths; fixed ACR bytes; 1024 TMDS video vectors and all control/TERC4/guard symbols')


if __name__ == '__main__':
    for path in sys.argv[1:]:
        if Path(path).name == 'primitives.txt': check_primitives(path)
        else: check(path)
