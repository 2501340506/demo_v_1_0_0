param([string]$RunName='lut24_sd_pin_boot1',[string]$Reference='v0.24.0-plan.1',[int]$Case=0,[int]$RunNs=60000000)
# Pin-level boot (real SD init/SPI driver + FAT32 scan) on the reference RTL
# and the working tree, with one shared set of selector fixtures.
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='d:/modelsim/win64'
$td='d:/TD/anlogic/TD6.2.1'
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
& $python -I -X utf8 "$root/diagnostics/disaster_selector/selector_fixtures.py" $out
if($LASTEXITCODE){throw 'fixtures failed'}
# Keep only this case's fixture exports; the 24 card images are not needed.
Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -match '^selector\d+(\.img|_bytes\.hex|_lba\.hex|_meta\.hex)$' -and $_.Name -notmatch "^selector$Case`_"} | ForEach-Object {Remove-Item -LiteralPath $_.FullName}
$referenceDir="$out/reference"
New-Item -ItemType Directory $referenceDir | Out-Null
git -C $root archive --format=zip -o "$out/reference.zip" $Reference user_source TD_project/demo.al
Expand-Archive -LiteralPath "$out/reference.zip" -DestinationPath $referenceDir
Remove-Item -LiteralPath "$out/reference.zip"
$vendor=Get-ChildItem "$td/sim_release/eg4/*.v","$td/sim_release/common/*.v" | ForEach-Object {$_.FullName}
foreach($side in @('reference','current')){
 $base=if($side -eq 'reference'){$referenceDir}else{$root}
 $lib="$out/${side}_work"
 & "$sim/vlib.exe" $lib *> "$out/$side.library.log"
 & "$sim/vlog.exe" -work $lib @vendor *> "$out/$side.vendor.log"
 if($LASTEXITCODE){throw "$side vendor compile"}
 [xml]$project=(Get-Content "$base/TD_project/demo.al" -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path').Replace('../user_source/',"$base/user_source/")})
 $enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
 $plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v' -and (Test-Path $_)})
 Push-Location "$base/TD_project"
 try{
  & "$sim/vlog.exe" -work $lib "+incdir+$base/user_source/hdl_source/include" @enc *> "$out/$side.encrypted.log"
  if($LASTEXITCODE){throw "$side encrypted compile"}
  & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib "+incdir+$base/user_source/hdl_source/include" @plain "$PSScriptRoot/tb_sd_pin_boot.sv" *> "$out/$side.compile.log"
  if($LASTEXITCODE){throw "$side compile; see $out/$side.compile.log"}
 }finally{Pop-Location}
}
Push-Location $out
try{
 foreach($side in @('reference','current')){
  & "$sim/vsim.exe" -c -quiet -lib "$out/${side}_work" tb_sd_pin_boot glbl "-gCASE_ID=$Case" "-gRUN_NS=$RunNs" -l "$out/$side.log" -do 'run -all; quit -f' *> "$out/$side.console.log"
  $text=Get-Content "$out/$side.log" -Raw
  Write-Output "== $side"
  [regex]::Matches($text,'(SD init[^\r\n]*|SCAN RESULT[^\r\n]*|FINAL[^\r\n]*|PASS sd pin boot|FAIL sd pin boot|\*\* (Fatal|Error)[^\r\n]*)') | ForEach-Object {$_.Value}
 }
}finally{Pop-Location}
# Fixture exports are regenerable; remove this case's copies after the runs.
Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -match '^selector\d+(\.img|_bytes\.hex|_lba\.hex|_meta\.hex)$'} | ForEach-Object {Remove-Item -LiteralPath $_.FullName}
