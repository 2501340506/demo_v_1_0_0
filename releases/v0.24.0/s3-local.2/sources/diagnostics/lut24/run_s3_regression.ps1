param([string]$Prefix='lut24_s3_reg1',[int[]]$ControllerCases=@(0..23),[switch]$ControllerOnly)
# S3 affected regressions. Shared BMP header: header/decoder equivalence,
# scale stream, FAT32 reader with SCALE_ENABLE (preflight and decode share
# one parser). Shared PCM/BIN streamer: stream/audio-control/voice
# equivalence, narration, controller cases (BIN, PCM and scaled decode).
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
if(!$ControllerOnly){
Step 'header equivalence' 'disaster_selector/run_header_equivalence.ps1' @('-RunName',"${Prefix}_header")
Step 'decoder equivalence' 'disaster_selector/run_decoder_equivalence.ps1' @('-RunName',"${Prefix}_decoder")
Step 'stream equivalence' 'disaster_selector/run_stream_equivalence.ps1' @('-RunName',"${Prefix}_stream")
Step 'audio control equivalence' 'disaster_selector/run_audio_control_equivalence.ps1' @('-RunName',"${Prefix}_audio_control")
Step 'voice equivalence' 'disaster_selector/run_voice_equivalence.ps1' @('-RunName',"${Prefix}_voice")
Step 'narration unit' 'narration_subtitles/run_unit.ps1' @('-RunName',"${Prefix}_narration")
# Scaled reader (shared preflight/decode parser) is compared with S2 by
# compare_reader_scale.ps1: case 24 expects the unscaled 4-cluster limit.
Write-Output '== fat32 reader cases scale=0'
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/run_reader_cases.ps1" -RunName "${Prefix}_reader_scale0" -ScaleTest 0
if($LASTEXITCODE){throw 'FAILED fat32 reader scale=0'}
}
foreach($id in $ControllerCases){
 $extra=@()
 if($id -eq 19){$extra=@('-ToneClockHz','25000000','-CheckAuto')}
 Step "controller case$id" 'disaster_selector/run_s2.ps1' (@('-RunName',"${Prefix}_ctrl$id",'-Cases',"$id")+$extra)
}
Step 'fast metrics' 'disaster_selector/run_fast_metrics.ps1' @('-RunName',"${Prefix}_fast_metrics")
Write-Output 'PASS S3 regression batch'
