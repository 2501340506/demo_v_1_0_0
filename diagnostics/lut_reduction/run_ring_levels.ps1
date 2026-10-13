param([string]$RunName='lut_ring_levels1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/audio_vis/audio_ring_levels.v" "$PSScriptRoot/audio_ring_levels_ref.v" "$PSScriptRoot/tb_ring_levels_equiv.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_ring_levels_equiv -l "$out/tb_ring_levels_equiv.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/tb_ring_levels_equiv.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error|Warning)'){throw "Test failed: $out/tb_ring_levels_equiv.log"}
 Write-Output "PASS tb_ring_levels_equiv"
}finally{Pop-Location}
