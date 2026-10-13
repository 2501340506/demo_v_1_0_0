param([string]$RunName='pcm_s2_units1',[string[]]$Tests=@('tb_audio_scan','tb_audio_mux','tb_audio_stream'))
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location $root
try {
 $rtl=@('user_source/hdl_source/SD/fat32_volume_scanner.v','user_source/hdl_source/SD/fat32_file_streamer.v','user_source/hdl_source/SD/sd_sector_adapter.v','user_source/hdl_source/SD/sd_sector_service.v','user_source/hdl_source/audio/fat32_pcm_stream.v','user_source/hdl_source/audio/pcm_stream_player.v','user_source/hdl_source/audio/audio_source_mux.v')
 $benches=@($Tests | ForEach-Object {"diagnostics/pcm_audio/$_.sv"})
 & "$sim/vlog.exe" -sv -work $lib @rtl @benches D:/TD/anlogic/TD6.2.1/sim_release/common/al_map_lut.v *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile failed'}
 foreach($test in $Tests){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $rc=$LASTEXITCODE;$x=Get-Content "$out/$test.log" -Raw
  if($rc -or $x -notmatch 'PASS ' -or $x -match '\*\* (Fatal|Error|Warning)' -or $x -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $out/$test.log"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
