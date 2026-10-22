param([string]$RunName='bottom_wave_unit01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
# Exercise both the legacy default and the production 80-entry history.
$test=Get-Content "$root/diagnostics/audio_vis/tb_audio_ring.sv" -Raw
$test=$test.Replace('tb_audio_ring','tb_wave_levels').Replace('audio_ring_levels levels','audio_ring_levels #(.BAR_COUNT(80)) levels').Replace('96','80').Replace('(n+64)','(n+80)')
[IO.File]::WriteAllText("$out/tb_wave_levels.sv",$test)
# v0.26 production: 40 entries mirrored about the centre.
$test=(Get-Content "$root/diagnostics/audio_vis/tb_audio_ring.sv" -Raw).Replace("tb_audio_ring","tb_wave_levels40").Replace("audio_ring_levels levels","audio_ring_levels #(.BAR_COUNT(40)) levels").Replace("96","40").Replace("(n+64)","(n+120)")
[IO.File]::WriteAllText("$out/tb_wave_levels40.sv",$test)
$rtl=Get-ChildItem "$root/user_source/hdl_source/audio_vis/*.v" | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -sv -work $lib E:/TD/sim_release/common/al_map_lut.v @rtl "$root/diagnostics/audio_vis/tb_audio_ring.sv" "$out/tb_wave_levels.sv" "$out/tb_wave_levels40.sv" "$PSScriptRoot/tb_wave_pixels.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try{
 foreach($name in @('tb_audio_ring','tb_wave_levels','tb_wave_levels40','tb_wave_pixels')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $name -l "$out/$name.log" -do 'run -all; quit -f' *> "$out/$name.console.log"
  $log=Get-Content "$out/$name.log" -Raw
  if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error):'){throw "Failed: $name"}
  Write-Output "PASS $name"
 }
}finally{Pop-Location}
