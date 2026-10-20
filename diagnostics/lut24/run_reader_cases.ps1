param([string]$RunName='lut24_reader1',[int[]]$Gaps=@(2,0))
# fat32/run_reader.ps1 cases with the same RTL list, fixtures and PASS text.
# The bench predates newer reader ports, so vopt reports unconnected-port
# (TFMPC vopt-2685/2718) warnings; any other warning or error still fails.
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$lib="$out/work".Replace('\','/')
$sim='d:/modelsim/win64'
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
Push-Location $root
try{
 & $python -I diagnostics/fat32/generate_core_fixtures.py "$out/fixtures"
 if($LASTEXITCODE){throw 'fixture generation failed'}
 & "$sim/vlib.exe" $lib *> "$out/library.log"
 $rtl=@('fat32_bmp_reader','sd_sector_adapter','sd_sector_service','fat32_volume_scanner','fat32_file_streamer','bmp_header_check','bmp24_decoder','bmp_scale_stream','bmp_sector_buffer','image_scale_nearest') | ForEach-Object {"user_source/hdl_source/SD/$_.v"}
 & "$sim/vlog.exe" -sv -work $lib -l "$out/compile.log" @rtl diagnostics/fat32/tb_fat32_reader.sv d:/TD/anlogic/TD6.2.1/sim_release/common/al_map_lut.v *> "$out/compile.console.log"
 if($LASTEXITCODE){throw 'compile failed'}
 $manifest=Get-Content "$out/fixtures/manifest.json" -Raw | ConvertFrom-Json
 $port=0
 foreach($gap in $Gaps){
  foreach($case in $manifest){
   $id=$case.id
   $log="$out/reader${id}_gap${gap}.log"
   & "$sim/vsim.exe" -c -quiet -lib $lib tb_fat32_reader "-gCASE_ID=$id" "-gBYTE_GAP=$gap" '-gTEST_MODE=0' '-gSCALE_TEST=0' "-gFIXTURE_DIR=$($out.Replace('\','/'))/fixtures" -l $log -do 'run -all; quit -f' *> "$out/case${id}_gap${gap}_console.log"
   $text=Get-Content $log -Raw
   $warnings=@([regex]::Matches($text,'\*\* Warning:[^\r\n]*') | ForEach-Object {$_.Value})
   $other=@($warnings | Where-Object {$_ -notmatch 'vopt-(2685|2718)\) \[TFMPC\]'})
   if($LASTEXITCODE -or $text -match '\*\* (Fatal|Error)' -or $text -notmatch 'PASS FAT32 reader' -or $other.Count){throw "reader case $id gap $gap failed: $log"}
   $port+=$warnings.Count
   Write-Output "PASS reader $id $($case.name) gap=$gap"
  }
 }
 Write-Output "PASS reader cases; only legacy unconnected-port warnings ($port total)"
}finally{Pop-Location}
