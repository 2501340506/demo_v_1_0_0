param([string]$RunName='mountain_m1_rgba01',[string]$SimRoot='F:/quartus18.1/modelsim_ase/win32aloem',[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$lib="$out/work".Replace('\','/')
& "$SimRoot/vlib.exe" $lib *> "$out/library.log"
$rtl=@('bmp_sector_buffer','bmp_header_check','bmp24_decoder','image_scale_nearest','bmp_scale_stream') | ForEach-Object {"$root/user_source/hdl_source/SD/$_.v"}
& "$SimRoot/vlog.exe" -sv -work $lib "$TdRoot/sim_release/common/al_map_lut.v" @rtl "$PSScriptRoot/tb_rgba_decoder.sv" "$PSScriptRoot/tb_rgba_stream.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compilation failed'}
Push-Location $out
try{
 foreach($test in @('tb_rgba_decoder','tb_rgba_stream')){
  & "$SimRoot/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content "$out/$test.log" -Raw
  if($LASTEXITCODE -or $log -notmatch 'PASS .*suite' -or $log -match '\*\* (Fatal|Error|Warning)'){throw "Failed $test"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
