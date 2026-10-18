param([string]$RunName='disaster_directories01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
& py -I -X utf8 "$PSScriptRoot/directory_fixtures.py" $out
if($LASTEXITCODE){throw 'fixture generation failed'}
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$PSScriptRoot/../../user_source/hdl_source/SD/fat32_lfn_directories.v" "$PSScriptRoot/../../user_source/hdl_source/SD/fat32_volume_scanner.v" "$PSScriptRoot/tb_directories.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile failed'}
Push-Location $out
try {
 foreach($id in 0..18){
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_directories "-gCASE_ID=$id" -l "$out/case$id.log" -do 'run -all; quit -f' *> "$out/case$id.console.log"
  $log=Get-Content -Raw "$out/case$id.log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS directories'){throw "directory case $id failed"}
  Write-Output "PASS directories $id"
 }
}finally{Pop-Location}
