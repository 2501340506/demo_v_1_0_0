"""List asynchronous set/reset nets in a TD physical netlist by driver type.

A slice output is 'f' (LUT/combinational) or 'q' (register). A reset net
driven from 'f' can glitch whenever its LUT inputs change; static timing does
not model that hazard. For every LUT-driven reset the LUT's input nets are
listed so the RTL source expression can be identified.
"""
import argparse
import collections
import re
from pathlib import Path


def parse(path):
    text = Path(path).read_text(encoding='utf-8', errors='replace')
    driver = {}      # net -> (instance, pin kind)
    inputs = {}      # instance -> {pin: net}
    users = collections.Counter()
    for inst in re.finditer(r'\n\s*(EG_PHY_\w+)\s*#\((.*?)\)\s*(\\\S+|\w+)\s*\((.*?)\);', text, re.S):
        kind, _, name, ports = inst.groups()
        pins = {}
        # Slice pins connect either one net or a {msb,lsb} concatenation.
        for pin, body in re.findall(r'\.(\w+)\(\s*(\{[^{}]*\}|[^(){}]*?)\s*\)', ports):
            nets = [n.strip() for n in body.strip('{}').split(',')] if body.startswith('{') else [body.strip()]
            for i, net in enumerate(reversed(nets)):
                if net and not net.startswith('open_n'):
                    pins[f'{pin}[{i}]'] = net
        inputs[name] = pins
        for pin, net in pins.items():
            base = pin.split('[')[0]
            if base in ('f', 'fx', 'q'):
                driver.setdefault(net, (name, base, kind))
            if base == 'sr':
                users[net] += 1
    return driver, inputs, users


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('netlist')
    p.add_argument('--filter', default='')
    a = p.parse_args()
    driver, inputs, users = parse(a.netlist)
    groups = collections.defaultdict(list)
    for net, count in users.items():
        if a.filter not in net:
            continue
        name, pin, kind = driver.get(net, ('<port/clock>', '?', '?'))
        groups['LUT' if pin in ('f', 'fx') else 'REG' if pin == 'q' else 'OTHER'].append((net, count, name))
    for key in ('LUT', 'OTHER', 'REG'):
        items = sorted(groups[key], key=lambda x: -x[1])
        print(f'== {key}-driven reset nets: {len(items)} nets, {sum(c for _, c, _ in items)} sr pins')
        if key == 'REG':
            continue
        for net, count, name in items:
            print(f'  {count:4d}  {net}')
            if name in inputs:
                ins = sorted(set(n for pin, n in inputs[name].items() if pin.split('[')[0] in ('a', 'b', 'c', 'd', 'e', 'mi')))
                for n in ins:
                    src = driver.get(n, ('?', '?', '?'))
                    print(f'          <- {n}  [{src[1]}]')


if __name__ == '__main__':
    main()
