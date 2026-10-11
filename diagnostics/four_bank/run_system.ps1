param([string]$RunName='four_bank_s3_system1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location "$root/TD_project"
try {
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v *> "$out/controller_compile.log"
 if($LASTEXITCODE){throw 'Controller compile failed'}
 & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/SD/sdram.v *> "$out/wrapper_compile.log"
 if($LASTEXITCODE){throw 'Wrapper compile failed'}
 $names=@('sd_card_bmp','media_frame_cache_control','media_frame_load_control','media_frame_loader','media_frame_reader','frame_fifo_read','frame_fifo_write','media_player_control','media_display_control','mode_key_control','key_press_debounce','fat32_bmp_reader','fat32_volume_scanner','fat32_file_streamer','sd_sector_adapter','sd_sector_service','bmp_header_check','bmp24_decoder','color_bar','video_timing_data','video_delay')
 $rtl=$names | ForEach-Object {"../user_source/hdl_source/SD/$_.v"}
 & "$sim/vlog.exe" -sv -work $lib @rtl ../user_source/hdl_source/video_transition_sd_control.v ../user_source/hdl_source/IP/afifo_16_32_256.v ../user_source/hdl_source/IP/afifo_32_16_256.v ../user_source/hdl_source/audio/media_commit_cdc.v ../user_source/hdl_source/audio/pcm_media_tone.v ../diagnostics/single_pll/sdram_bl4_model.sv ../diagnostics/four_bank/tb_cache_system.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_cache_system -l "$out/system.log" -do 'run -all; quit -f' *> "$out/console.log"
 $rc=$LASTEXITCODE;$log=Get-Content "$out/system.log" -Raw
 if($rc -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS cache system:' -or $log -notmatch 'Errors: 0,'){throw "Cache system failed: $out/system.log"}
 $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch 'vopt-(2685|2718|2121)'})
 if($unexpected.Count){throw "Unexpected warnings: $unexpected"}
 Write-Output "PASS full cache system: $out/system.log"
}finally{Pop-Location}
