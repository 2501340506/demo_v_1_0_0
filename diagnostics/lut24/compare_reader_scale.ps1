param([string]$RunName='lut24_reader_scale_compare1',[string]$Reference='HEAD')
# FAT32 reader fixtures with SCALE_ENABLE=1 (shared preflight/decode header
# parser) against the reader RTL at $Reference. Every case and byte gap must
# give the same PASS/Fatal line, including found and request counts. The
# scaled streamer keeps 16384 visited clusters, so case 24 (built for the
# unscaled 4-cluster limit) is expected to report the same failure on both.
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path "$out/reference_src" | Out-Null
$sim='d:/modelsim/win64'
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
$almap='d:/TD/anlogic/TD6.2.1/sim_release/common/al_map_lut.v'
$names=@('fat32_bmp_reader','sd_sector_adapter','sd_sector_service','fat32_volume_scanner','fat32_file_streamer','bmp_header_check','bmp24_decoder','bmp_scale_stream','bmp_sector_buffer','image_scale_nearest')
Push-Location $root
try{
 & $python -I diagnostics/fat32/generate_core_fixtures.py "$out/fixtures"
 if($LASTEXITCODE){throw 'fixture generation failed'}
 foreach($name in $names){
  $text=(git show "${Reference}:user_source/hdl_source/SD/$name.v") -join "`n"
  [IO.File]::WriteAllText("$out/reference_src/$name.v",$text)
 }
 $libs=@{reference="$out/reference_work".Replace('\','/');current="$out/current_work".Replace('\','/')}
 $sources=@{reference=@($names | ForEach-Object {"$out/reference_src/$_.v"});current=@($names | ForEach-Object {"user_source/hdl_source/SD/$_.v"})}
 foreach($side in @('reference','current')){
  & "$sim/vlib.exe" $libs[$side] *> "$out/$side.library.log"
  & "$sim/vlog.exe" -sv -work $libs[$side] @($sources[$side]) diagnostics/fat32/tb_fat32_reader.sv $almap *> "$out/$side.compile.log"
  if($LASTEXITCODE){throw "$side compile failed"}
 }
 $manifest=Get-Content "$out/fixtures/manifest.json" -Raw | ConvertFrom-Json
 $differences=0;$passes=0
 foreach($gap in @(2,0)){
  foreach($case in $manifest){
   $id=$case.id;$lines=@{}
   foreach($side in @('reference','current')){
    $log="$out/${side}_case${id}_gap$gap.log"
    & "$sim/vsim.exe" -c -quiet -lib $libs[$side] tb_fat32_reader "-gCASE_ID=$id" "-gBYTE_GAP=$gap" '-gTEST_MODE=0' '-gSCALE_TEST=1' "-gFIXTURE_DIR=$($out.Replace('\','/'))/fixtures" -l $log -do 'run -all; quit -f' *> "$out/${side}_case${id}_gap${gap}_console.log"
    $lines[$side]=([regex]::Match((Get-Content $log -Raw),'(PASS FAT32 reader[^\r\n]*|\*\* Fatal:[^\r\n]*)')).Value
   }
   if(!$lines.current -or $lines.reference -ne $lines.current){$differences++;Write-Output "DIFF case $id gap $gap : $($lines.reference) | $($lines.current)"}
   elseif($lines.current -like 'PASS*'){$passes++}
   else{Write-Output "SAME case $id gap $gap : $($lines.current)"}
  }
 }
 if($differences){throw "$differences scaled reader results differ from $Reference"}
 Write-Output "PASS scaled reader identical to $Reference ($passes passing runs)"
}finally{Pop-Location}
