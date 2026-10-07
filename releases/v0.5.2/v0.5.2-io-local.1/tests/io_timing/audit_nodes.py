"""Explain TD dummy pins from the emitted physical netlist, keeping each pin visible."""
import argparse
import collections
import pathlib
import re

p = argparse.ArgumentParser()
p.add_argument('check', type=pathlib.Path)
p.add_argument('netlist', type=pathlib.Path)
p.add_argument('output', type=pathlib.Path)
a = p.parse_args()
net = a.netlist.read_text(encoding='utf-8')
cells = {}
for m in re.finditer(r'(EG_PHY_\w+)\s+#\((.*?)\)\s*\\(\S+)\s+\((.*?)\);', net, re.S):
    params = dict(re.findall(r'^\s*\.(\w+)\((.*?)\)', m[2], re.M))
    ports = dict(re.findall(r'^\s*\.(\w+)\((.*?)\)', m[4], re.M))
    cells[m[3]] = (m[1], params, ports, m[0])

def bit(expr, index):
    if expr is None:
        return 'unconnected'
    if expr.startswith('{'):
        return expr[1:-1].split(',')[-1-index].strip()
    return expr.strip() + f' [bit {index}]'

def unused(expr):
    return expr.startswith(('open_n', 'unconnected'))

rows = []
details = []
seen = set()
for sec in a.check.read_text().split('DummyNode in Model: ')[1:]:
    model, _, tail = sec.partition('\n')
    pins = [x.strip() for x in tail.split('\n\n')[0].splitlines() if x.startswith('\t')]
    for pin in pins:
        name, port = pin.rsplit('.', 1)
        typ, params, ports, block = cells[name]
        reason = 'UNRESOLVED'
        if typ in ('EG_PHY_LSLICE', 'EG_PHY_MSLICE'):
            stem, idx = re.fullmatch(r'(\w+)\[(\d+)\]', port).groups()
            i = int(idx)
            q = bit(ports.get('q'), i)
            f = bit(ports.get('f'), i)
            fx = bit(ports.get('fx'), i)
            if stem == 'mi' and unused(q):
                reason = 'unused register data input; q unconnected'
            elif stem in ('a', 'b', 'c', 'd', 'e') and unused(f) and unused(fx) and (unused(q) or params.get(f'REG{i}_SD') == '"MI"') and 'fco' not in ports:
                reason = 'unused LUT half; f/fx unconnected; register absent or MI bypass'
        elif typ == 'EG_PHY_PAD' and re.search(r"\.do\(\{[^}]*1'b[01]\}\)", block):
            reason = 'constant SDRAM control output (CS=0 / CKE=1)'
        elif typ == 'EG_PHY_MULT18' and port == 'a[17]' and ports.get('b') == "18'b000000000000000001" and ports.get('p','').startswith('{open_n'):
            reason = 'multiply by 1; upper product bits unused, a[17] cannot affect retained lower bits'
        rows.append((pin, typ, reason))
        if name not in seen:
            details.append(block)
            seen.add(name)

counts = collections.Counter(r[2] for r in rows)
lines = ['# TD dummy-node audit', '', 'Each row is a reported pin; TD header count is model groups, not this pin count.', '', '| Pin | Model | Disposition |', '|---|---|---|']
lines += ['| ' + ' | '.join(x.replace('|', '/') for x in r) + ' |' for r in rows]
lines += ['', '## Counts', ''] + [f'- {k}: {v}' for k, v in counts.items()]
a.output.write_text('\n'.join(lines)+'\n', encoding='utf-8')
a.output.with_suffix('.netlist.txt').write_text('\n\n'.join(details), encoding='utf-8')
print(dict(counts))
if counts['UNRESOLVED']:
    raise SystemExit(1)
