"""Compare S3 with the accepted S2 legacy parser on identical sector inputs."""
from pathlib import Path
import re, subprocess
root=Path(__file__).resolve().parents[2]
out=root/'diagnostics/output/decoder_s3_ab'
out.mkdir(parents=True,exist_ok=True)
sim=Path('D:/modelsim/win64')
lib=(out/'work').as_posix()
def run(exe,args,log):
    r=subprocess.run([str(sim/exe),*args],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    (out/log).write_text(r.stdout,encoding='utf-8')
    if r.returncode or re.search(r'\*\* (?:Error|Fatal|Warning)',r.stdout):
        raise RuntimeError(log)
    return r.stdout
if not (out/'work/_info').exists():run('vlib.exe',[lib],'library.log')
old=(root/'releases/v0.6.0-bmp211/s2-local.1/sources/hdl_source/SD/bmp_read.v').read_text(encoding='utf-8-sig')
(out/'bmp_read_s2.v').write_text(old.replace('module bmp_read #(','module bmp_read_s2 #('),encoding='utf-8')
widths={'ready':1,'scan_done':1,'scan_error':1,'scan_found_valid':1,'scan_found_sector':32,'scan_found_total':3,'load_done':1,'load_error':1,'bmp_error':3,'write_req':1,'sd_sec_read':1,'sd_sec_read_addr':32,'bmp_data_wr_en':1,'bmp_data':24}
for suite in ['baseline','headers','scan','pixels','timeout']:
    tb=(root/f'diagnostics/stability/tb_bmp_{suite}.sv').read_text(encoding='utf-8-sig')
    m=re.search(r'bmp_read\s*(#\(.*?\))?\s+dut\s*\((.*?)\);',tb,re.S)
    if not m:raise RuntimeError(suite)
    param=m[1] or '#()'
    param=param[:-1]+(', ' if m[1] else '')+'.USE_DECODER(0))'
    body=m[2]; decl=[]; checks=[]; pairs={}
    for port,expr in re.findall(r'\.(\w+)\(([^()]*)\)',body):
        if port not in widths or not expr.strip():continue
        pairs[port]=expr
        decl.append(f'wire [{widths[port]-1}:0] ref_{port};')
        body=body.replace(f'.{port}({expr})',f'.{port}(ref_{port})')
    for port,expr in pairs.items():
        if port=='load_done':checks.append(f'if ({expr} !== previous_done) $fatal(1,"A/B completion latency");')
        elif port=='ready':checks.append(f'if(ref_ready !== {expr} && !ref_load_done) $fatal(1,"A/B ready");')
        elif port=='bmp_data':checks.append(f'if(ref_bmp_data_wr_en && ref_bmp_data !== {expr}) $fatal(1,"A/B RGB");')
        else:checks.append(f'if(ref_{port} !== {expr}) $fatal(1,"A/B {port}");')
    if 'load_done' not in pairs:decl.append("wire ref_load_done=1'b0;")
    checker='\n'.join(decl)+f'\nbmp_read_s2 {param} reference ({body});\nreg previous_done=0;\nalways @(negedge clk) begin\nif(rst) previous_done=0; else begin\n'+'\n'.join(checks)+'\nprevious_done=ref_load_done;\nend\nend\n'
    tb=tb[:m.end()]+checker+tb[m.end():]
    target=out/f'tb_bmp_{suite}.sv';target.write_text(tb,encoding='utf-8')
    files=[root/'user_source/hdl_source/SD'/f'{n}.v' for n in ['bmp_header_check','bmp24_decoder','bmp_read']]
    files += [out/'bmp_read_s2.v',root/'diagnostics/stability/sim_bmp_sectors.sv',target]
    run('vlog.exe',['-sv','-work',lib,*[f.as_posix() for f in files]],f'compile_{suite}.log')
    result=run('vsim.exe',['-c','-quiet','-lib',lib,f'tb_bmp_{suite}','-do','run -all; quit -f'],f'test_{suite}.log')
    if 'PASS ' not in result or 'Errors: 0, Warnings: 0' not in result:raise RuntimeError(suite)
    print('PASS S2/S3 '+suite,flush=True)
