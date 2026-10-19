"""Convert existing UART text to events.csv and paired interval records.

T values are hexadecimal milliseconds since reset. Pending event arbitration
adds a few control clocks; DROP means the log cannot prove complete coverage.
This parser never substitutes a missing endpoint or measures power-on/HDMI lock.
"""
import argparse
import csv
from pathlib import Path
import re

LINE = re.compile(r'(?P<event>[A-Z_]+)\s+T=(?P<time>[0-9A-Fa-f]{8})\s+I=(?P<image>[0-3])\s+S=(?P<sector>[0-9A-Fa-f]{8})\s+E=(?P<error>[0-9A-Fa-f])\s+P=(?P<phase>[0-9A-Fa-f])')
PHASE = {4:'source_done',5:'writer_done',6:'optional_bins_ready',8:'preflight_done',
         9:'menu_enter',10:'menu_ready',11:'scene_confirm',14:'sdram_ready'}


def parse(text):
    rows = []
    for number, line in enumerate(text.splitlines(), 1):
        match = LINE.search(line)
        if not match:
            continue
        d = match.groupdict()
        event, phase = d['event'], int(d['phase'], 16)
        rows.append(dict(line=number, ms=int(d['time'],16), event=PHASE.get(phase,event) if event=='WAIT' else event,
                         image=int(d['image']), sector=int(d['sector'],16), error=int(d['error'],16), phase=phase))
    return rows


def intervals(rows):
    starts = {}
    first_commit = False
    result = []
    for row in rows:
        event, at = row['event'], row['ms']
        if event in ('SCAN_START','LOAD','menu_enter','scene_confirm'):
            starts[event] = at
        if event == 'COMMIT' and not first_commit:
            result.append(dict(interval='reset_to_first_commit',start_ms=0,end_ms=at,elapsed_ms=at))
            first_commit = True
        for begin, end, label in (('SCAN_START','SCAN_DONE','scan'),('LOAD','source_done','decode'),
                                  ('LOAD','writer_done','write_drain'),('menu_enter','menu_ready','menu'),
                                  ('scene_confirm','COMMIT','selected_first_frame')):
            if event == end and begin in starts:
                start = starts[begin]
                elapsed = (at-start) & 0xffffffff
                result.append(dict(interval=label,start_ms=start,end_ms=at,elapsed_ms=elapsed))
                if begin in ('menu_enter','scene_confirm','SCAN_START'):
                    del starts[begin]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    text = args.log.read_text(encoding='utf-8-sig')
    rows = parse(text)
    if not rows:
        raise SystemExit('No UART records found')
    args.out.mkdir(parents=True, exist_ok=False)
    for name, records, keys in (('events.csv', rows, ('line','ms','event','image','sector','error','phase')),
                               ('intervals.csv', intervals(rows), ('interval','start_ms','end_ms','elapsed_ms'))):
        with (args.out/name).open('w', newline='', encoding='utf-8-sig') as f:
            writer = csv.DictWriter(f, keys);writer.writeheader();writer.writerows(records)
    print(f'Parsed {len(rows)} events. Reset log must contain one boot only; missing intervals remain absent.')
    if re.search(r'\bDROP\b', text):
        print('DROP present: log is incomplete; repeat measurement before accepting timing.')


if __name__ == '__main__':
    main()
