"""Archive S2 module evidence, without a bitstream or hardware candidate tag."""
from pathlib import Path
import re
import shutil
import subprocess

root=Path(__file__).resolve().parents[2]
output=root/'diagnostics/output'
dest=root/'releases/v0.12.0/s2-modules'
if dest.exists(): raise SystemExit('S2 archive already exists')
logs=[output/'pcm_s2_player_exact2/player.log']
logs += list((output/'pcm_s2_units_final1').glob('tb_*.log'))
logs=[p for p in logs if not p.name.endswith('.console.log')]
logs += [output/f'pcm_s2_reader_final2/reader{i}_gap2_mode0.log' for i in range(42)]
for p in logs:
    s=p.read_text(errors='replace')
    if 'PASS ' not in s or 'Errors: 0, Warnings: 0' not in s or re.search(r'\*\* (Fatal|Error|Warning):',s):
        raise SystemExit(f'Incomplete simulation: {p}')
modules=['pcm_stream_player','fat32_pcm_stream','audio_source_mux','audio_scan_synthesis']
for m in modules:
    work=output/'pcm_s2_syn2'/m
    if not (work/'demo_gate.area').exists(): raise SystemExit(f'No synthesis result: {m}')
    for source in work.glob('*.v'):
        candidates=list((root/'user_source/hdl_source').rglob(source.name))
        if not candidates: candidates=[root/'diagnostics/pcm_audio'/source.name]
        if len(candidates)!=1 or source.read_bytes()!=candidates[0].read_bytes():
            raise SystemExit(f'Synthesis source differs: {source}')
result=output/'pcm_s2_conversion1/RESULT.txt'
if not result.read_text().startswith('PASS conversion:'): raise SystemExit('No conversion evidence')

def copy(source,target):
    target=dest/target
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)
    if source.read_bytes()!=target.read_bytes(): raise SystemExit(f'Copy differs: {target}')

for p in logs: copy(p,Path('simulation')/p.relative_to(output))
for m in modules:
    work=output/'pcm_s2_syn2'/m
    for name in ['demo_gate.area','build.log']:
        copy(work/name,Path('synthesis')/m/name)
    for p in work.glob('*.logw'): copy(p,Path('synthesis')/m/p.name)
for name in ['RESULT.txt','BGM.PCM','audition_440Hz.wav','signed_endpoints.pcm']:
    copy(output/'pcm_s2_conversion1'/name,Path('samples')/name)
changed=subprocess.check_output(['git','diff','v0.12.0-s1-board.1','--name-only','--','user_source','tools'],cwd=root,text=True).splitlines()
changed+=subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','user_source','tools'],cwd=root,text=True).splitlines()
for name in sorted(set(changed)): copy(root/name,Path('changes')/name)
lines=['S2 module validation only; no bitstream and no local/board tag.',
       'Baseline: v0.12.0-s1-board.1',f'Simulation logs: {len(logs)}','Changed source files:']+sorted(set(changed))
lines+=['','Files and sizes:']+[f'{p.relative_to(dest).as_posix()} {p.stat().st_size}' for p in sorted(dest.rglob('*')) if p.is_file()]
(dest/'SOURCE_MANIFEST.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'Archived S2: {len(logs)} passing logs, four synthesis results, conversion corpus; no bitstream')
