param([string]$RunName='fast_preview05')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
& py -I -X utf8 "$PSScriptRoot/check_request_mux.py" *> "$out/mux_proof.txt"
if($LASTEXITCODE){throw 'Arbitration equivalence failed'}
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/media_preview_control.v" "$root/diagnostics/image_scaling/tb_preview_control.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Preview compile failed'}
Push-Location $out
try {
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_preview_control -l "$out/preview.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/preview.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS preview control:' -or $log -notmatch 'Errors: 0,' -or $log -match '\*\* (Fatal|Error):'){throw 'Preview target simulation failed'}
 Write-Output 'PASS preview target ownership, rescan inhibition and arbitration equivalence'
}finally{Pop-Location}
