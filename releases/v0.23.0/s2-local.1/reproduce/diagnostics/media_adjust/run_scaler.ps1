param([string]$RunName='adjust_scaler_hold1',[string]$SimRoot='F:/modelsim/win64',[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim=$SimRoot;$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=@('bmp_sector_buffer','bmp_header_check','bmp24_decoder','image_scale_nearest','bmp_scale_stream') | ForEach-Object {"$root/user_source/hdl_source/SD/$_.v"}
& "$sim/vlog.exe" -sv -work $lib "$TdRoot/sim_release/common/al_map_lut.v" @rtl "$root/diagnostics/image_scaling/tb_scaler.sv" "$root/diagnostics/image_scaling/tb_scale_stream.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try {
 foreach($test in @('tb_scaler','tb_scale_stream')) {
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content "$out/$test.log" -Raw
  if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error):'){throw "Failed: $test"}
  Write-Output "PASS $test"
 }
} finally {Pop-Location}
