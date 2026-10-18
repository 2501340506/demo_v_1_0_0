param([string]$RunName='disaster_s2_controller01',
 [ValidateSet('controller','display','pixels')][string]$Suite='controller',
 [int[]]$Cases=@(0))
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
& py -I -X utf8 "$PSScriptRoot/selector_fixtures.py" $out
if($LASTEXITCODE){throw 'fixtures failed'}
if($Suite -eq 'pixels'){
 & py -I -X utf8 "$PSScriptRoot/menu_reference.py" $out
 if($LASTEXITCODE){throw 'menu reference failed'}
}
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'vendor compile'}
Push-Location "$root/TD_project"
try {
 [xml]$project=(Get-Content demo.al -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path')})
 $enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
 $plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v'})
 & "$sim/vlog.exe" -work $lib '../user_source/ip_source/s3_single_pll/sys_pll_s3.v' *> "$out/pll.log"
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' @enc *> "$out/encrypted.log"
 if($LASTEXITCODE){throw 'encrypted compile'}
 & "$sim/vlog.exe" -sv '+define+SIMULATION' -work $lib '+incdir+../user_source/hdl_source/include' @plain "$root/diagnostics/single_pll/sdram_bl4_model.sv" "$PSScriptRoot/tb_selector_$Suite.sv" *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile failed'}
}finally{Pop-Location}
Push-Location $out
try {
 foreach($id in $Cases){
  & "$sim/vsim.exe" -c -quiet -lib $lib "tb_selector_$Suite" glbl "-gCASE_ID=$id" -l "$out/case$id.log" -do 'run -all; quit -f' *> "$out/case$id.console.log"
  $log=Get-Content -Raw "$out/case$id.log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS selector'){throw "FAIL case $id $out"}
  Write-Output "PASS selector $Suite case $id"
 }
}finally{Pop-Location}
if($Suite -eq 'pixels'){
 & py -I -X utf8 -c 'from PIL import Image; import sys; Image.open(sys.argv[1]).save(sys.argv[2])' "$out/menu_actual.ppm" "$out/menu_actual.png"
 if($LASTEXITCODE){throw 'pixel preview conversion failed'}
}
