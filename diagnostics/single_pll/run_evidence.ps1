param([string]$OutputDirectory = 'diagnostics/output/v052_evidence_replay')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
$sim = 'D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$lib = (Join-Path $out 'work').Replace('\','/')
$failed = @()
Push-Location "$root/TD_project"
try {
    if (!(Test-Path "$lib/_info")) {
        & "$sim/vlib.exe" $lib
        if ($LASTEXITCODE) { throw 'vlib failed' }
    }
    & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v 2>&1 | Tee-Object "$out/controller_compile.log"
    if ($LASTEXITCODE) { throw 'controller compile failed' }
    $rtl = @('media_display_control','media_player_control','media_policy','key_gesture_control','key_press_debounce','mode_key_control','dual_key_event_router','sd_card_bmp','frame_fifo_read','frame_fifo_write','frame_read_write','bmp_header_check','bmp24_decoder','bmp_read') | ForEach-Object { "../user_source/hdl_source/SD/$_.v" }
    foreach ($test in @('tb_refresh_service','tb_full_frame_evidence','tb_full_rescan_evidence','tb_full_refresh_trace')) {
        $benches = @("../diagnostics/single_pll/$test.sv")
        if ($test -eq 'tb_full_refresh_trace') { $benches = @('../diagnostics/single_pll/tb_full_frame_evidence.sv') + $benches }
        & "$sim/vlog.exe" -sv -work $lib '+incdir+../user_source/hdl_source/include' @rtl @benches 2>&1 | Tee-Object "$out/${test}_compile.log"
        if ($LASTEXITCODE) { throw "compile failed: $test" }
        $log = "$out/$test.log"
        & "$sim/vsim.exe" -c -quiet -lib $lib $test -l $log -do 'run -all; quit -f'
        $result = Get-Content $log -Raw
        if ($LASTEXITCODE -ne 0 -or $result -match '\*\* (Fatal|Error):' -or $result -notmatch '# PASS ' -or $result -notmatch 'Errors: 0, Warnings: 0') {
            $failed += $test
        }
    }
    if ($failed.Count) { throw "Evidence contains failing tests: $($failed -join ', '). Logs retained in $out" }
} finally { Pop-Location }
