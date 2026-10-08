param([string]$OutputDirectory='diagnostics/output/refresh_fix', [ValidateSet('all','full','rescan')][string]$Test='all')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=[IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$lib=(Join-Path $out 'work').Replace('\','/')
Push-Location "$root/TD_project"
try {
 if(!(Test-Path "$lib/_info")) { & "$sim/vlib.exe" $lib; if($LASTEXITCODE){throw 'vlib failed'} }
 $rtl=@('media_display_control','media_player_control','media_policy','key_gesture_control','key_press_debounce','mode_key_control','dual_key_event_router','sd_card_bmp','frame_fifo_read','frame_fifo_write','frame_read_write','bmp_header_check','bmp24_decoder','bmp_read') | ForEach-Object { "../user_source/hdl_source/SD/$_.v" }
 # SIMULATION must never leak into the protected controller: it changes read latency.
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v 2>&1 | Tee-Object "$out/controller_compile.log"
 if($LASTEXITCODE){throw 'controller compile failed'}
 & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/SD/sdram.v 2>&1 | Tee-Object "$out/wrapper_compile.log"
 if($LASTEXITCODE){throw 'wrapper compile failed'}
 & "$sim/vlog.exe" -sv -work $lib @rtl ../user_source/hdl_source/IP/afifo_16_32_256.v ../user_source/hdl_source/IP/afifo_32_16_256.v ../diagnostics/single_pll/sdram_bl4_model.sv 2>&1 | Tee-Object "$out/compile.log"
 if($LASTEXITCODE){throw 'RTL compile failed'}
 foreach($case in @(@('tb_full_frame_evidence','tb_full_sdram_data'),@('tb_full_rescan_evidence','tb_rescan_sdram_data'))) {
   if($Test -eq 'full' -and $case[1] -ne 'tb_full_sdram_data'){continue}
   if($Test -eq 'rescan' -and $case[1] -ne 'tb_rescan_sdram_data'){continue}
   & "$sim/vlog.exe" -sv +define+USE_PRODUCTION_FIFO -work $lib "../diagnostics/single_pll/$($case[0]).sv" "../diagnostics/single_pll/$($case[1]).sv" 2>&1 | Tee-Object "$out/$($case[1])_compile.log"
   if($LASTEXITCODE){throw 'bench compile failed'}
   $log="$out/$($case[1]).log"
   & "$sim/vsim.exe" -c -quiet -lib $lib $case[1] -l $log -do 'run -all; quit -f'
   $rc=$LASTEXITCODE
   $result=Get-Content $log -Raw
   if($rc -ne 0 -or $result -match '\*\* (Fatal|Error):' -or $result -notmatch 'Errors: 0,' -or $result -notmatch 'RESULT production_schedule refs=\d+ min_gap=1100 max_gap=1100 violations=0' -or $result -notmatch '# PASS (real BMP plus asynchronous|rescan real BMP)') {throw "Failed: $log"}
 }
} finally { Pop-Location }
