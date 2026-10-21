param([string]$Prefix='lut24_s1_reg1')
# S1 affected regressions. Each legacy script runs through invoke_legacy.ps1
# for the current ModelSim/TD/Python locations; any failure stops the batch.
$ErrorActionPreference='Stop'
$legacy="$PSScriptRoot/invoke_legacy.ps1"
$d=Join-Path $PSScriptRoot '..'
function Step([string]$label,[string]$script,[string[]]$arguments){
 Write-Output "== $label"
 & powershell -NoProfile -ExecutionPolicy Bypass -File $legacy -Script (Join-Path $d $script) @arguments
 $code=$LASTEXITCODE
 # Selector card images are regenerated per run (~4.9 GB); keep logs only.
 if($script -like '*run_s2.ps1' -or $script -like '*run_fast_metrics.ps1'){
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/remove_selector_fixtures.ps1" -RunName $arguments[1]
 }
 if($code){throw "FAILED $label"}
}
Write-Output '== fat32 reader cases'
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/run_reader_cases.ps1" -RunName "${Prefix}_reader"
if($LASTEXITCODE){throw 'FAILED fat32 reader'}
Step 'directories' 'disaster_selector/run_directories.ps1' @('-RunName',"${Prefix}_directories")
Step 'lfn' 'disaster_selector/run_lfn.ps1' @('-RunName',"${Prefix}_lfn")
Step 'controller case0' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl0",'-Cases','0')
Step 'controller case16' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl16",'-Cases','16')
Step 'controller case18' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl18",'-Cases','18')
Step 'controller case19 auto' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl19",'-Cases','19','-ToneClockHz','25000000','-CheckAuto')
Write-Output 'PASS S1 regression batch'
