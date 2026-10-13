param([string]$RunName='lut_seg_equiv1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/seg7_panel.v" "$root/user_source/hdl_source/SD/seg_scan.v" "$root/user_source/hdl_source/SD/seg_decoder.v" "$PSScriptRoot/seg7_panel_ref.v" "$PSScriptRoot/seg_scan_ref.v" "$PSScriptRoot/tb_seg_equiv.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_seg_equiv -l "$out/tb_seg_equiv.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/tb_seg_equiv.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error|Warning)'){throw "Test failed: $out/tb_seg_equiv.log"}
 Write-Output "PASS tb_seg_equiv"
}finally{Pop-Location}
