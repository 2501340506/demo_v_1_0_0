param([string]$RunName='fast_metrics01',[switch]$Baseline)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
$arg=if($Baseline){'baseline'}else{'current'}
& py -I -X utf8 "$PSScriptRoot/prepare_fast_metrics.py" $out $arg
if($LASTEXITCODE){throw 'prepare metrics'}
& py -I -X utf8 "$PSScriptRoot/selector_fixtures.py" $out
if($LASTEXITCODE){throw 'fixtures'}
$sourceRoot=if($Baseline){$out}else{$root}
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'vendor'}
[xml]$project=((git -C $root show HEAD:TD_project/demo.al) -join "`n").Replace('UsedInP&R','UsedInP&amp;R')
$rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path').Replace('../user_source/',"$sourceRoot/user_source/")})
$enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
$plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v'})
Push-Location "$sourceRoot/TD_project"
try {
& "$sim/vlog.exe" -work $lib "$sourceRoot/user_source/ip_source/s3_single_pll/sys_pll_s3.v" *> "$out/pll.log"
& "$sim/vlog.exe" -work $lib "+incdir+$sourceRoot/user_source/hdl_source/include" @enc *> "$out/encrypted.log"
if($LASTEXITCODE){throw 'encrypted'}
& "$sim/vlog.exe" -sv +define+SIMULATION -work $lib "+incdir+$sourceRoot/user_source/hdl_source/include" @plain "$out/tb_selector_controller.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'compile'}
}finally{Pop-Location}
Push-Location $out
try {
 foreach($id in @(0,11,16)){
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_selector_controller glbl "-gCASE_ID=$id" -l "$out/case$id.log" -do 'run -all; quit -f' *> "$out/case$id.console.log"
  $log=Get-Content -Raw "$out/case$id.log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS selector metrics'){throw "metrics case $id"}
  $log -split "`n" | Where-Object {$_ -cmatch '^# (METRIC |PASS selector metrics)'} | Set-Content "$out/metrics$id.txt" -Encoding UTF8
  Write-Output "PASS metrics case $id baseline=$Baseline"
 }
}finally{Pop-Location}
