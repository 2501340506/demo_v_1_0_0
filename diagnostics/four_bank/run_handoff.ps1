param([string]$RunName='four_bank_s1_handoff')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
& python "$PSScriptRoot/prepare_handoff.py" $out
if($LASTEXITCODE){throw 'Harness preparation failed'}
Push-Location $root
try{
 foreach($test in @('tb_pixel_handoff','tb_rescan_handoff')){
  $lib=(Join-Path $out $test).Replace('\','/')
  if(!(Test-Path "$lib/_info")){& "$sim/vlib.exe" $lib;if($LASTEXITCODE){throw 'vlib failed'}}
  $rtl=@('media_frame_loader','media_frame_reader','media_display_control','media_player_control','media_policy','key_gesture_control','key_press_debounce','mode_key_control','dual_key_event_router','sd_sector_adapter','sd_card_bmp','frame_fifo_read','frame_fifo_write','bmp_header_check','fat32_bmp_reader','fat32_volume_scanner','fat32_file_streamer','bmp24_decoder','bmp_read') | ForEach-Object {"user_source/hdl_source/SD/$_.v"}
  & "$sim/vlog.exe" -sv -work $lib @rtl diagnostics/four_bank/frame_split_test_adapter.sv "$out/$test.sv" *> "$out/${test}_compile.log"
  if($LASTEXITCODE){throw "Compile failed: $test"}
  foreach($scenario in @(@(17,2),@(19,16),@(23,64))){
   $name="$($test)_$($scenario[0])_$($scenario[1])"
   & "$sim/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $test "-gPIX_HALF=$($scenario[0])" "-gSOURCE_GAP=$($scenario[1])" -l "$out/$name.log" -do 'run -all; quit -f' *> "$out/$name.console.log"
   $rc=$LASTEXITCODE;$log=Get-Content "$out/$name.log" -Raw
   if($rc -ne 0 -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS (real BMP plus asynchronous|rescan real BMP)' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Handoff failed: $out/$name.log"}
   Write-Output "PASS split $name"
  }
 }
}finally{Pop-Location}
