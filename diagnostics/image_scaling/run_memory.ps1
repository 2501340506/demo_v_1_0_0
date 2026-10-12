param([string]$RunName='scale_memory1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$lib="$out/work".Replace('\','/')
& D:/modelsim/win64/vlib.exe $lib *> "$out/library.log"
Push-Location "$root/TD_project"
try {
 & D:/modelsim/win64/vlog.exe -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v *> "$out/controller_compile.log"
 if($LASTEXITCODE){throw 'controller compile'}
 & D:/modelsim/win64/vlog.exe -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/SD/sdram.v ../user_source/hdl_source/SD/thumbnail_address.v ../diagnostics/single_pll/sdram_bl4_model.sv ../diagnostics/image_scaling/tb_thumbnail_memory.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile'}
 & D:/modelsim/win64/vsim.exe -c -quiet -lib $lib tb_thumbnail_memory -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/sim.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS thumbnail physical memory suite'){throw "FAIL $out"}
 Write-Output "PASS $out"
}finally{Pop-Location}
