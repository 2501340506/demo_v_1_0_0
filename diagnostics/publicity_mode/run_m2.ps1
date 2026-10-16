param([string]$RunName='publicity_m2_attempt01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
& py -I -X utf8 "$PSScriptRoot/prepare_m2.py" $out
if($LASTEXITCODE){throw 'Prepare failed'}
& py -I -X utf8 "$root/diagnostics/fat32/generate_core_fixtures.py" "$out/fixtures" *> "$out/fixtures.log"
if($LASTEXITCODE){throw 'Fixtures failed'}
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=@('fat32_bmp_reader','sd_sector_adapter','sd_sector_service','fat32_volume_scanner','fat32_file_streamer','bmp_header_check','bmp24_decoder','bmp_scale_stream','bmp_sector_buffer','image_scale_nearest') | ForEach-Object {"$root/user_source/hdl_source/SD/$_.v"}
$benches=@("$PSScriptRoot/tb_publicity_scan.sv","$PSScriptRoot/tb_publicity_reader.sv","$out/tb_snd_scan.sv","$out/tb_audio_scan.sv","$out/tb_fat32_core.sv","$out/tb_m5_scan_equivalence.sv","$out/tb_fat32_reader_equivalence.sv")
& "$sim/vlog.exe" -sv -work $lib @rtl @benches "$out/fat32_volume_scanner_reference.v" "$out/fat32_bmp_reader_reference.v" 'E:/TD/sim_release/common/al_map_lut.v' *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out"}
function Run-Test([string]$top,[string]$name,[string[]]$params){
 & "$sim/vsim.exe" -c -quiet -lib $lib $top @params -l "$out/$name.log" -do 'run -all; quit -f' *> "$out/$name.console.log"
 $log=Get-Content -Raw "$out/$name.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error|Warning)' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Failed $name : $out"}
 Write-Output "PASS $name"
}
foreach($gap in @(0,2,5)){
 foreach($top in @('tb_publicity_scan','tb_publicity_reader','tb_m5_scan_equivalence','tb_snd_scan','tb_audio_scan')){Run-Test $top "${top}_gap$gap" @("-gGAP=$gap")}
}
$fixture=$out.Replace('\','/')+'/fixtures'
$manifest=Get-Content -Raw "$out/fixtures/manifest.json" | ConvertFrom-Json
foreach($case in $manifest){
 Run-Test tb_fat32_core "core_$($case.id)" @("-gCASE_ID=$($case.id)",'-gBYTE_GAP=2')
 Run-Test tb_fat32_reader_equivalence "reader_eq_$($case.id)" @("-gCASE_ID=$($case.id)",'-gBYTE_GAP=2',"-gFIXTURE_DIR=$fixture")
}
foreach($mode in @(1,2,3,4,5)){
 Run-Test tb_fat32_reader_equivalence "reader_eq_mode$mode" @('-gCASE_ID=0','-gBYTE_GAP=0',"-gTEST_MODE=$mode","-gFIXTURE_DIR=$fixture")
}
foreach($case in @(0,5,6,37)){
 Run-Test tb_fat32_reader_equivalence "reader_eq_scale$case" @("-gCASE_ID=$case",'-gBYTE_GAP=0','-gSCALE_TEST=1',"-gFIXTURE_DIR=$fixture")
}
Write-Output "PASS M2 simulation/regression output=$out"
