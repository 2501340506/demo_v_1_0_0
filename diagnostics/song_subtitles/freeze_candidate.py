"""Freeze a timing-clean 21px black Song narration candidate; compare full bytes."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TARGET=ROOT/'releases/v0.22.0/s1-local.1'
ASSETS=ROOT/'diagnostics/output/song_assets01'
RUNS=('song_unit01','song_integration01','song_scene_text01')


def read(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')


def copy(source,relative):
    dest=TARGET/relative
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,dest)
    assert dest.read_bytes()==source.read_bytes(),relative


def freeze(name):
    build=ROOT/'diagnostics/output'/name
    phy=build/'TD_project/demo_Runs/phy_1'
    metrics={k:float(re.search(k+r':\s*([-\d.]+)ns',read(phy/'final_timing.rpt'))[1]) for k in ('SWNS','HWNS','STNS','HTNS')}
    assert metrics['SWNS']>0 and metrics['HWNS']>0 and metrics['STNS']==metrics['HTNS']==0
    assert not TARGET.exists(),'Use a new candidate number'
    for stage in ('syn_1','phy_1'):
        log=read(build/f'TD_project/demo_Runs/{stage}/build_{name}.log')
        assert not re.search(r'\bERROR:',log)
        if stage=='phy_1':assert 'Generate bitstream completely' in log
    review=json.loads((build/'timing_audit/warning_review.json').read_text(encoding='utf-8'))
    assert review['reviewed'] and review['font_rom_initialization_verified']
    checked=[]
    for source in (build/'user_source').rglob('*'):
        if source.is_file():
            relative=source.relative_to(build)
            assert source.read_bytes()==(ROOT/relative).read_bytes(),str(relative)
            checked.append(relative.as_posix())
    for relative in ('card/TEXT.BIN','manifest.json','font_rows.hex','text_words.hex','font_rom.v'):
        assert (ASSETS/relative).read_bytes()==(ROOT/'diagnostics/output/song_assets02'/relative).read_bytes(),relative
    assert (ROOT/'user_source/hdl_source/scene/scene_text_overlay.v').read_text(encoding='utf-8').endswith((ASSETS/'font_rom.v').read_text(encoding='ascii'))
    subtitles=json.loads((ASSETS/'manifest.json').read_text(encoding='utf-8'))
    assert subtitles['font_size']==21 and subtitles['foreground']==[0,0,0] and subtitles['band'] is None
    tests=[]
    for run in RUNS:
        for source in (ROOT/'diagnostics/output'/run).rglob('*.log'):
            if source.name.endswith('.console.log') or source.name=='console.log':continue
            log=read(source)
            if 'PASS ' in log and 'Errors: 0,' in log:
                assert not re.search(r'\*\* (Fatal|Error):',log)
                tests.append(source.relative_to(ROOT/'diagnostics/output').as_posix())
    assert len(tests)==9,tests
    area=read(phy/'demo_phy.area')
    resources={k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M)[1]) for k in ('lut','reg','bram','bram32k','dsp')}
    assert resources['lut']<=19600 and resources['bram']<=64 and resources['bram32k']<=16 and resources['dsp']<=29
    copy(phy/'demo.bit','demo.bit')
    changed=subprocess.check_output(['git','diff','--name-only','34fce4d','HEAD'],cwd=ROOT,text=True,encoding='utf-8').splitlines()
    production=[p for p in changed if p.startswith('user_source/')]
    assert production==['user_source/hdl_source/scene/scene_text_overlay.v'],production
    helpers=('tools/publicity/make_narration_subtitles.py','diagnostics/narration_subtitles/run_unit.ps1',
             'diagnostics/narration_subtitles/tb_narration.sv','diagnostics/narration_subtitles/tb_narration_top.sv',
             'diagnostics/narration_subtitles/check_font_map.py','diagnostics/narration_subtitles/update_card.py',
             'diagnostics/song_subtitles/review_build.py','diagnostics/song_subtitles/freeze_candidate.py',
             'diagnostics/bottom_waveform/run_integration.ps1','diagnostics/bottom_waveform/run_td.ps1')
    for relative in production+list(helpers):copy(ROOT/relative,'sources/'+relative)
    copy(build/'TD_project/demo.al','reproduce/demo.al')
    copy(ROOT/'diagnostics/run_td_build.ps1','reproduce/run_td_build.ps1')
    for p in ('final_timing.rpt','demo_phy.area','settings.cfg',f'build_{name}.log'):copy(phy/p,'reports/'+p)
    for p in ('demo_gate.area','settings.cfg',f'build_{name}.log'):copy(build/'TD_project/demo_Runs/syn_1'/p,'reports/synthesis/'+p)
    for p in ('check_timing.txt','exceptions.timing','sw3_sync.timing','console.log','exceptions.log','audit.tcl','exceptions.tcl','warning_review.json','font_rom_check.json'):
        copy(build/'timing_audit'/p,'reports/audit/'+p)
    copy(ROOT/'user_source/constraints_source/timing.sdc','reports/timing.sdc')
    (TARGET/'reports/source_check.json').write_text(json.dumps(dict(method='full byte comparison',files=checked),indent=2)+'\n',encoding='utf-8')
    for p in tests:copy(ROOT/'diagnostics/output'/p,'validation/'+p)
    for run in RUNS:
        for p in ('compile.log','vendor.log','pll.log','encrypted.log'):
            source=ROOT/'diagnostics/output'/run/p
            if source.exists():copy(source,'validation/'+run+'/'+p)
    for p in ('card/TEXT.BIN','manifest.json','font_rows.hex','text_words.hex'):copy(ASSETS/p,p if p!='manifest.json' else 'subtitles.json')
    for source in (ASSETS/'preview').glob('*.png'):copy(source,'preview/'+source.name)
    copy(ROOT/'releases/v0.21.0/s1-local.1/card/TEXT.BIN','rollback/TEXT.BIN')
    (TARGET/'.gitattributes').write_text('* -text\n',encoding='utf-8')
    manifest=dict(baseline='34fce4d / v0.21.0-s1-local.1',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  build=name,timing_ns=metrics,resources=resources,source_byte_comparisons=len(checked),
                  production_files=production,simulation_logs=tests,board_status='pending',card_status='not yet written',files=[])
    manifest['files']=[dict(file=p.relative_to(TARGET).as_posix(),bytes=p.stat().st_size) for p in sorted(TARGET.rglob('*')) if p.is_file()]
    (TARGET/'MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS frozen',TARGET,metrics,resources,len(tests),'simulations')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',required=True)
    freeze(p.parse_args().build)
