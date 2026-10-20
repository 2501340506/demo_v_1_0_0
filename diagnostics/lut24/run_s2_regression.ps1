param([string]$Prefix='lut24_s2_reg1')
# S2 affected regressions (plan list). Legacy scripts run through
# invoke_legacy.ps1 for the current tool locations; any failure stops the batch.
$ErrorActionPreference='Stop'
$legacy="$PSScriptRoot/invoke_legacy.ps1"
$d=Join-Path $PSScriptRoot '..'
function Step([string]$label,[string]$script,[string[]]$arguments){
 Write-Output "== $label"
 & powershell -NoProfile -ExecutionPolicy Bypass -File $legacy -Script (Join-Path $d $script) @arguments
 if($LASTEXITCODE){throw "FAILED $label"}
}
Write-Output '== fat32 reader cases'
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/run_reader_cases.ps1" -RunName "${Prefix}_reader"
if($LASTEXITCODE){throw 'FAILED fat32 reader'}
Step 'directories' 'disaster_selector/run_directories.ps1' @('-RunName',"${Prefix}_directories")
Step 'lfn' 'disaster_selector/run_lfn.ps1' @('-RunName',"${Prefix}_lfn")
Step 'audio control equivalence' 'disaster_selector/run_audio_control_equivalence.ps1' @('-RunName',"${Prefix}_audio_control")
Step 'voice equivalence' 'disaster_selector/run_voice_equivalence.ps1' @('-RunName',"${Prefix}_voice")
Step 'stream equivalence' 'disaster_selector/run_stream_equivalence.ps1' @('-RunName',"${Prefix}_stream")
Step 'controller case0' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl0",'-Cases','0')
Step 'controller case16' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl16",'-Cases','16')
Step 'controller case18' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl18",'-Cases','18')
Step 'controller case19 auto' 'disaster_selector/run_s2.ps1' @('-RunName',"${Prefix}_ctrl19",'-Cases','19','-ToneClockHz','25000000','-CheckAuto')
Step 'fast metrics' 'disaster_selector/run_fast_metrics.ps1' @('-RunName',"${Prefix}_fast_metrics")
Step 'four bank system' 'four_bank/run_system.ps1' @('-RunName',"${Prefix}_four_bank")
Write-Output 'PASS S2 regression batch'
