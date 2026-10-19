"""Create blank board measurement sheets or summarize measured milliseconds."""
import argparse
import csv
from pathlib import Path
from statistics import median


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('csv', type=Path)
    p.add_argument('--template', action='store_true')
    a = p.parse_args()
    if a.template:
        with a.csv.open('x', encoding='utf-8-sig', newline='') as f:
            w = csv.writer(f)
            w.writerow(('build', 'test', 'run', 'elapsed_ms', 'notes'))
            for build in ('baseline', 'candidate'):
                for test in ('boot_power', 'boot_reset', 'menu', 'confirm'):
                    for run in range(1, 11):
                        w.writerow((build, test, run, '', ''))
        print('Blank template created; no measurements supplied.')
        return
    groups = {}
    with a.csv.open(encoding='utf-8-sig', newline='') as f:
        for row in csv.DictReader(f):
            if not row['elapsed_ms'].strip():
                continue
            value = float(row['elapsed_ms'])
            if not 0 <= value < float('inf'):
                raise ValueError('elapsed_ms must be finite and nonnegative')
            key = row['build'], row['test']
            runs = groups.setdefault(key, {})
            run = int(row['run'])
            if run in runs:
                raise ValueError(f'Duplicate run: {key} {run}')
            runs[run] = value
    if not groups:
        print('No measured values; board timing remains unverified.')
    for (build, test), runs in sorted(groups.items()):
        values = list(runs.values())
        state = '10 runs complete' if set(runs) == set(range(1, 11)) else 'INCOMPLETE'
        print(f'{build}/{test}: n={len(values)} median={median(values):g} ms max={max(values):g} ms ({state})')


if __name__ == '__main__':
    main()
