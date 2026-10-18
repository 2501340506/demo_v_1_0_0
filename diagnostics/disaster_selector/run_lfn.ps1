param([string]$RunName='disaster_lfn01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
& py -I -X utf8 "$PSScriptRoot/lfn_vectors.py" $out
if($LASTEXITCODE){throw 'fixture generation failed'}
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$PSScriptRoot/../../user_source/hdl_source/SD/fat32_lfn_directories.v" "$PSScriptRoot/tb_lfn.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
Push-Location $out
try {
 $count=Get-Content lfn_count.txt
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_lfn "+ENTRIES=$count" -l "$out/tb_lfn.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content -Raw "$out/tb_lfn.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS VFAT'){throw 'LFN test failed'}
 Write-Output 'PASS VFAT'
}finally{Pop-Location}
