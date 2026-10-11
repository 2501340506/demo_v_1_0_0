param([string]$RunName='pcm_s1_service1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location $root
try {
 & "$sim/vlog.exe" -sv -work $lib user_source/hdl_source/SD/sd_sector_adapter.v user_source/hdl_source/SD/sd_sector_service.v diagnostics/pcm_audio/tb_sd_sector_service.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw 'Compilation failed'}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_sd_sector_service -l "$out/service.log" -do 'run -all; quit -f' *> "$out/console.log"
 $rc=$LASTEXITCODE;$log=Get-Content "$out/service.log" -Raw
 if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS sector service:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Service test failed: $out/service.log"}
 Write-Output "PASS sector service: $out/service.log"
}finally{Pop-Location}
