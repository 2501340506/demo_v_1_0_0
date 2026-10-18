param([string]$RunName='disaster_s2_spi01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
$rtl=@('sd_card_cmd','sd_card_sec_read_write','sd_card_top','spi_master') | ForEach-Object {"$root/user_source/hdl_source/SD/$_.v"}
Push-Location $out
try{
 foreach($test in @('tb_sd_protocol','tb_sd_initialization','tb_sd_spi_pins','tb_sd_init_retry')){
  & "$sim/vlog.exe" -sv -work $lib @rtl "$root/diagnostics/sd_recovery/$test.sv" *> "$out/${test}_compile.log"
  if($LASTEXITCODE){throw "Compile failed: $test"}
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/${test}_console.log"
  $log=Get-Content -Raw "$out/$test.log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Failed: $test"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
