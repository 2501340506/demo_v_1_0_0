"""Freeze a verified narration bit and its matching PS1 resource. No hashes."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TARGET=ROOT/'releases/v0.21.0/s1-local.1'
ASSETS=ROOT/'diagnostics/output/narration_assets02'


def read(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')


def copy(source,rel):
    dest=TARGET/rel
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,dest)
    assert dest.read_bytes()==source.read_bytes()


def main(name):
    build=ROOT/'diagnostics/output'/name
    phy=build/'TD_project/demo_Runs/phy_1'
    timing=read(phy/'final_timing.rpt')
    metrics={key:float(re.search(key+r':\s*([-\d.]+)ns',timing)[1]) for key in ('SWNS','HWNS','STNS','HTNS')}
    assert metrics['SWNS']>0 and metrics['HWNS']>0 and metrics['STNS']==metrics['HTNS']==0
    assert not TARGET.exists(),'Candidate is immutable'
    for run in ('syn_1','phy_1'):
        log=read(build/f'TD_project/demo_Runs/{run}/build_{name}.log')
        assert not re.search(r'\bERROR:',log)
        if run=='phy_1':assert 'Generate bitstream completely' in log
    review=json.loads((build/'timing_audit/warning_review.json').read_text(encoding='utf-8'))
    assert review['reviewed'] and review['font_rom_initialization_verified']
    checked=[]
    for source in (build/'user_source').rglob('*'):
        if source.is_file():
            rel=source.relative_to(build)
            assert source.read_bytes()==(ROOT/rel).read_bytes(),str(rel)
            checked.append(rel.as_posix())
    for rel in ('card/TEXT.BIN','manifest.json','font_rows.hex','text_words.hex','font_rom.v'):
        assert (ASSETS/rel).read_bytes()==(ROOT/'diagnostics/output/narration_assets03'/rel).read_bytes(),rel
    rom=(ROOT/'user_source/hdl_source/scene/scene_text_overlay.v').read_text(encoding='utf-8')
    assert rom.endswith((ASSETS/'font_rom.v').read_text(encoding='ascii'))
    tests=[]
    for run in ('narration_unit01','narration_integration02','narration_scene_text01','narration_audio01','narration_parameters01'):
        folder=ROOT/'diagnostics/output'/run
        for source in folder.rglob('*.log'):
            if source.name.endswith(('.console.log',)) or source.name=='console.log':continue
            log=read(source)
            if 'PASS ' in log and 'Errors: 0,' in log:
                assert not re.search(r'\*\* (Fatal|Error):',log)
                rel=source.relative_to(folder).as_posix()
                tests.append(run+'/'+rel)
    assert len(tests)==25,tests
    copy(phy/'demo.bit','demo.bit')
    changed=subprocess.check_output(['git','diff','--name-only','ef3c545','HEAD'],cwd=ROOT,text=True,encoding='utf-8').splitlines()
    production=[p for p in changed if p.startswith('user_source/')]
    for p in production:copy(ROOT/p,'sources/'+p)
    for p in ('tools/publicity/make_narration_subtitles.py','diagnostics/narration_subtitles/run_unit.ps1',
              'diagnostics/narration_subtitles/tb_narration.sv','diagnostics/narration_subtitles/tb_narration_top.sv',
              'diagnostics/narration_subtitles/update_card.py','diagnostics/narration_subtitles/freeze_candidate.py',
              'diagnostics/bottom_waveform/run_integration.ps1','diagnostics/bottom_waveform/run_td.ps1'):
        copy(ROOT/p,'sources/'+p)
    copy(build/'TD_project/demo.al','reproduce/demo.al')
    copy(ROOT/'diagnostics/run_td_build.ps1','reproduce/run_td_build.ps1')
    for p in ('final_timing.rpt','demo_phy.area','settings.cfg',f'build_{name}.log'):
        copy(phy/p,'reports/'+p)
    for p in ('demo_gate.area','settings.cfg',f'build_{name}.log'):
        copy(build/'TD_project/demo_Runs/syn_1'/p,'reports/synthesis/'+p)
    for p in ('audit.timing','check_timing.txt','exceptions.timing','sw3_sync.timing','console.log',
              'exceptions.log','audit.tcl','exceptions.tcl','warning_review.json','font_rom_check.json'):
        copy(build/'timing_audit'/p,'reports/audit/'+p)
    copy(ROOT/'user_source/constraints_source/timing.sdc','reports/timing.sdc')
    (TARGET/'reports/source_check.json').write_text(json.dumps(dict(method='full byte comparison',files=checked),indent=2)+'\n',encoding='utf-8')
    for p in tests:copy(ROOT/'diagnostics/output'/p,'validation/'+p)
    for run in ('narration_unit01','narration_integration02','narration_scene_text01','narration_audio01','narration_parameters01'):
        for p in ('compile.log','vendor.log','pll.log','encrypted.log'):
            source=ROOT/'diagnostics/output'/run/p
            if source.exists():copy(source,'validation/'+run+'/'+p)
    for p in ('card/TEXT.BIN','manifest.json','font_rows.hex','text_words.hex'):
        copy(ASSETS/p,p if p!='manifest.json' else 'subtitles.json')
    for source in (ASSETS/'preview').glob('*.png'):copy(source,'preview/'+source.name)
    area=read(phy/'demo_phy.area')
    resources={key:int(re.search(r'^#'+key+r'\s+(\d+)',area,re.M)[1]) for key in ('lut','reg','bram','bram32k','dsp')}
    manifest=dict(baseline='ef3c545 / v0.20.0-s1-local.1',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  build=name,timing_ns=metrics,resources=resources,source_byte_comparisons=len(checked),
                  production_files=production,simulation_logs=tests,board_status='pending',files=[])
    for p in TARGET.rglob('*'):
        if p.is_file():manifest['files'].append(dict(file=p.relative_to(TARGET).as_posix(),bytes=p.stat().st_size))
    (TARGET/'MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (TARGET/'.gitattributes').write_text('* -text\n',encoding='utf-8')
    print('PASS frozen:',TARGET,metrics,resources,len(tests),'tests')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',required=True)
    main(p.parse_args().build)
