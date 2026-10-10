param([string]$RunName='osd_opt_alpha1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/osd/osd_pixel_position.v" "$root/user_source/hdl_source/osd/osd_alpha_band.v" "$PSScriptRoot/tb_alpha.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try {
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_alpha -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $rc=$LASTEXITCODE;$log=Get-Content "$out/sim.log" -Raw
 if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS alpha band:' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "OSD test failed: $out/sim.log"}
 Write-Output "PASS alpha band: $out/sim.log"
}finally{Pop-Location}
