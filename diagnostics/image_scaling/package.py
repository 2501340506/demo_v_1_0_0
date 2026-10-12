"""Freeze only a fully validated S2 candidate; never overwrite a candidate."""
from pathlib import Path
import argparse,re,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('build');p.add_argument('--candidate',default='s2-local.1');a=p.parse_args()
root=Path(__file__).resolve().parents[2];output=root/'diagnostics/output';build=output/a.build
phy=build/'TD_project/demo_Runs/phy_1';release=root/'releases/v0.14.0'/a.candidate
timing=(phy/'final_timing.rpt').read_text(errors='replace')
for m in ('SWNS','HWNS'):
    value=re.search(m+r':\s*([-\d.]+)ns',timing)
    assert value and float(value[1])>=0,f'Timing failed: {m}'
inputs=[Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"',(root/inputs[0]).read_text(encoding='utf-8')):
    inputs.append((root/'TD_project'/name).resolve().relative_to(root))
for name in inputs:assert (root/name).read_bytes()==(build/name).read_bytes(),f'Changed build input {name}'
logs={
 'scale_unit2/sim.log':'PASS scaler suite',
 'scale_stream2/sim.log':'PASS byte stream suite',
 'scale_geometry2/sim.log':'PASS range header',
 'scale_memory4/sim.log':'PASS thumbnail physical memory suite',
 'scale_decoder_legacy2/sim.log':'PASS decoder',
 'scale_s2_system4/system.log':'PASS cache system:',
 'scale_s2_mixed5/system.log':'PASS mixed physical system:',
 'scale_s2_paths1/paths.log':'PASS frame paths:',
 'scale_s2_hdmi_final1/tb_pcm_production.log':'PASS production PCM:',
 'scale_s2_fragment_final1/reader0_gap2_mode0.log':'PASS FAT32 reader',
}
for folder,glob,marker in [('scale_s2_regression2','tb_*.log','PASS '),('scale_s2_fat32_final1','reader*_gap2_mode0.log','PASS FAT32 reader')]:
    found=[f for f in (output/folder).glob(glob) if '.console.' not in f.name]
    assert len(found)==(21 if 'regression' in folder else 42),(folder,len(found))
    for f in found:logs[f.relative_to(output).as_posix()]=marker
for name,marker in logs.items():
    text=(output/name).read_text(errors='replace')
    assert marker in text and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error):',text),name
assert (build/'timing_audit/check_timing.txt').exists(),'Missing timing audit'
assert not release.exists(),'Never overwrite a candidate'
release.mkdir(parents=True)
def copy(src,dst):
    target=release/dst;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,target)
    assert src.read_bytes()==target.read_bytes(),str(dst)
copy(phy/'demo.bit',Path('demo.bit'))
for name in ['final_timing.rpt','demo_phy.area']:copy(phy/name,Path('reports')/name)
copy(phy/f'build_{a.build}.log',Path('reports/build_phy.log'))
copy(build/f'TD_project/demo_Runs/syn_1/build_{a.build}.log',Path('reports/build_syn.log'))
for name in ['check_timing.txt','audit.timing']:copy(build/'timing_audit'/name,Path('reports')/name)
for name in logs:copy(output/name,Path('validation')/name)
changed=subprocess.check_output(['git','diff','v0.13.0','--name-only','--','user_source','TD_project'],cwd=root,text=True).splitlines()
changed=[Path(n) for n in changed if Path(n) in inputs]
for name in changed:copy(root/name,Path('sources')/name)
copy(root/'diagnostics/image_scaling/S2_VALIDATION.md',Path('VALIDATION.md'))
copy(root/'diagnostics/image_scaling/BOARD_GUIDE.md',Path('BOARD_VALIDATION.md'))
copy(output/'scale_board_samples1/board_samples.zip',Path('board_samples.zip'))
for f in (output/'scale_board_samples1').glob('*_expected.png'):copy(f,Path('preview')/f.name)
manifest=['# S2 candidate inputs','',f'Baseline v0.13.0; build {a.build}; bit {(phy/"demo.bit").stat().st_size} bytes.',
          f'{len(inputs)} project inputs compared byte-for-byte with build; {len(changed)} changed production inputs copied.',
          f'{len(logs)} verified simulation logs. Remaining inputs referenced through baseline.','']
manifest += [f'- {n.as_posix()} ({(root/n).stat().st_size} bytes)' for n in inputs]
(release/'MANIFEST.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')
(release/'README.md').write_text(f'''# v0.14.0 {a.candidate}：全屏图片缩放

本地候选，尚未板测。基线 v0.13.0；构建 {a.build}。开发分支 feature/image-scaling-thumbnails。

[固定 bit](demo.bit) · [四张测试 BMP 和参考图](board_samples.zip) · [板测步骤](BOARD_VALIDATION.md) · [验证记录](VALIDATION.md) · [输入清单](MANIFEST.md)

支持正高度、24 位、非压缩 BMP：宽不超过 1920 且高不超过 1080，或宽不超过 1080 且高不超过 1920。加载时采用最近邻等比缩放、居中黑边，输出保持 640×480；四个全屏 bank 地址及像素格式不变。图片 FAT 链上限 16384 簇，扇区缓存和 ready/valid 控制放大时的背压。读 FIFO 补充优先及整 64 字启动修正保障显示和间歇输入。

S2 仅接入全屏缩放；四宫格及 11 模式交互在 S2 板测通过后的 S3 接入。字幕、圆环、转场和音乐沿用全屏行为。大图首次加载需读取全部源文件，实际板级加载时间待测。

完整 TD Setup +0.107ns、Hold +0.035ns，STA 覆盖率 99.97%；15716 LUT、8260 寄存器、41 BRAM9K、10 DSP、1 PLL，约束未修改。详细功能结果及历史失败见验证记录。

bit 为 {(phy/'demo.bit').stat().st_size} 字节，归档与构建产物逐字节一致；{len(inputs)} 个工程输入与构建快照逐字节一致。仅归档相对基线变化的 {len(changed)} 个生产输入，未改输入通过基线引用。

回退：[v0.13.0/demo.bit](../../v0.13.0/demo.bit)。用户确认本候选功能通过后记录 board 标签并推送分支和阶段标签，再继续 S3。20 分钟持续播放、Flash 和完全断电冷启动留在最终 S4，不以本地测试替代。
''',encoding='utf-8')
print(f'Packaged {release}: {len(inputs)} inputs, {len(logs)} logs, {len(changed)} changed inputs')
