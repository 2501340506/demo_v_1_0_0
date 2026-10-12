param([string]$RunName='ring_s1_unit1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=Get-ChildItem "$root/user_source/hdl_source/audio_vis/*.v" | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -sv -work $lib @rtl "$PSScriptRoot/tb_audio_ring.sv" "$PSScriptRoot/tb_ring_pixels.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try{
 foreach($test in @('tb_audio_ring','tb_ring_pixels')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content "$out/$test.log" -Raw
  if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error):'){throw "Test failed: $out/$test.log"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
