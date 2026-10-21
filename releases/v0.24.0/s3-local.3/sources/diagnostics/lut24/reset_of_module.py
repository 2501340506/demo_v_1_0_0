"""Report which asynchronous reset nets reach registers of a given hierarchy
in a TD physical netlist, and whether each net is driven by a slice LUT (f)
or a register (q). Instances are scanned line by line (no full-text regex)."""
import argparse
import collections
import re
from pathlib import Path


def nets(body):
    body = body.strip()
    parts = body.strip('{}').split(',') if body.startswith('{') else [body]
    return [p.strip() for p in parts if p.strip() and not p.strip().startswith('open_n')]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('netlist')
    ap.add_argument('prefixes', nargs='+')
    a = ap.parse_args()
    driver = {}
    users = collections.defaultdict(collections.Counter)
    name = None
    for line in Path(a.netlist).read_text(encoding='utf-8', errors='replace').splitlines():
        s = line.strip()
        if s.startswith(chr(92)) and s.endswith('('):
            name = s[1:].split()[0]
            continue
        m = re.match(r'\.(\w+)\((.*)\)[,)]', s)
        if not m or name is None:
            continue
        pin, body = m.groups()
        for net in nets(body):
            if pin in ('f', 'fx', 'q'):
                driver.setdefault(net, (pin, name))
            if pin == 'sr':
                for p in a.prefixes:
                    if name.startswith(p):
                        users[p][net] += 1
    for p in a.prefixes:
        print('==', p)
        for net, count in users[p].most_common():
            pin, src = driver.get(net, ('?', '?'))
            print(f'  {count:4d} sr  {net}  <- .{pin} of {src}')


if __name__ == '__main__':
    main()
