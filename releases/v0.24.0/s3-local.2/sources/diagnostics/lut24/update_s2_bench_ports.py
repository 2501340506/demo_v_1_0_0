"""v0.24 S2: rename scanner/reader file-table ports in legacy benches.

Only empty connections .name() are rewritten: the old per-entry table outputs
become the indexed read ports, with the index tied to zero. Benches that read
any removed table output are reported and left unchanged.
"""
import re
import sys

REMOVED = ['resource0_cluster', 'resource1_cluster', 'resource2_cluster', 'resource3_cluster',
           'resource0_size', 'resource1_size', 'resource2_size', 'resource3_size',
           'thumb_cluster', 'thumb_size', 'audio_cluster', 'audio_size',
           'snd_clusters', 'snd_sizes', 'edu_clusters', 'edu_sizes',
           'voi_clusters', 'voi_sizes', 'pic_clusters', 'pic_sizes']
SCANNER_NEW = ".image_index(4'd0),.image_cluster(),.image_size(),.audio_index(4'd0),.audio_entry_cluster(),.audio_entry_size(),"
READER_NEW = ".audio_index(4'd0),.audio_entry_cluster(),.audio_entry_size(),"

for path in sys.argv[1:]:
    raw = open(path, 'rb').read()
    crlf = b'\r\n' in raw
    text = raw.decode('utf-8').replace('\r\n', '\n')
    used = [n for n in REMOVED if re.search(r'\.' + n + r'\(\s*[^)\s]', text)]
    if used:
        print(f'SKIP {path}: connected {used}')
        continue
    count = 0
    first = None
    for name in REMOVED:
        pattern = re.compile(r'\.' + name + r'\(\s*\)\s*,?')
        for m in pattern.finditer(text):
            if first is None or m.start() < first:
                first = m.start()
        text, n = pattern.subn('', text)
        count += n
    if count == 0:
        print(f'NOCHANGE {path}')
        continue
    reader = 'fat32_bmp_reader' in text and 'fat32_volume_scanner' not in text
    text = text[:first] + (READER_NEW if reader else SCANNER_NEW) + text[first:]
    if crlf:
        text = text.replace('\n', '\r\n')
    open(path, 'w', encoding='utf-8', newline='').write(text)
    print(f'UPDATED {path}: {count} connections ({"reader" if reader else "scanner"})')
