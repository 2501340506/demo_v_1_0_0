param([string]$Prefix='mountain_m1_verify',[string]$SimRoot='F:/quartus18.1/modelsim_ase/win32aloem',[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$common=@{SimRoot=$SimRoot;TdRoot=$TdRoot}
& "$PSScriptRoot/run_legacy.ps1" @common -Suite decoder -RunName "${Prefix}_decoder"
& "$PSScriptRoot/run_rgba.ps1" @common -RunName "${Prefix}_rgba"
& "$PSScriptRoot/run_legacy.ps1" @common -Suite scaler -RunName "${Prefix}_scaler"
foreach($gap in @(0,2)){
 & "$PSScriptRoot/run_legacy.ps1" @common -Suite reader -ByteGap $gap -RunName "${Prefix}_reader$gap"
}
& "$PSScriptRoot/run_legacy.ps1" @common -Suite reader32 -ByteGap 0 -RunName "${Prefix}_reader32"
foreach($mode in 1..5){
 & "$PSScriptRoot/run_legacy.ps1" @common -Suite reader -Cases @(0) -ByteGap 0 -TestMode $mode -RunName "${Prefix}_mode$mode"
}
foreach($suite in @('reader','reader32')){
 & "$PSScriptRoot/run_legacy.ps1" @common -Suite $suite -Cases @(0) -ScaleTest 1 -ByteGap 0 -RunName "${Prefix}_${suite}_scaled"
}
& "$PSScriptRoot/run_legacy.ps1" @common -Suite rgba_system -RunName "${Prefix}_memory"
& "$PSScriptRoot/run_legacy.ps1" @common -Suite pcm -RunName "${Prefix}_pcm"
& "$PSScriptRoot/run_legacy.ps1" @common -Suite preview -Mixed 1 -Audio -Failures -RunName "${Prefix}_preview"
& "$PSScriptRoot/run_legacy.ps1" @common -Suite system -RunName "${Prefix}_system"
