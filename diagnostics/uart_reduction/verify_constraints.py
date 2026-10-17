"""Verify the real TD SDC probe against enabled and constant UART databases."""
from pathlib import Path
import re
import sys

folder = Path(sys.argv[1])


def read(name):
    raw = (folder / name).read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8')


constraint = 'set_max_delay -from [get_clocks sd_card_clk] -to [get_ports uart_tx] 10.000 -datapath_only'
enabled = read('enabled.exceptions')
disabled = read('disabled.exceptions')
assert constraint in enabled and constraint not in disabled
assert re.search(r'\b1\s+1\s+0\s+0\s+' + re.escape(constraint), enabled)
assert 'UART_LOG_COUNT=316' in read('enabled.log')
assert 'UART_LOG_COUNT=0' in read('disabled.log')
for name in ('enabled.log', 'disabled.log'):
    assert not re.search(r'\bERROR[: ]', read(name), re.I)
print('PASS UART constraint guard: live UART max-delay retains one path; constant TX max-delay absent')
