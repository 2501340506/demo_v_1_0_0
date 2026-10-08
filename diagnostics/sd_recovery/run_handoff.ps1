$ErrorActionPreference = 'Stop'
$simTools = 'D:/modelsim/win64'
$simDir = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../output'))) 'modelsim_check'
$simLib = (Join-Path $simDir 'rescan_handoff_work').Replace('\', '/')
Push-Location ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')))
try {
    if (-not (Test-Path -LiteralPath "$simLib/_info")) {
        New-Item -ItemType Directory -Path $simDir -Force | Out-Null
        & "$simTools/vlib.exe" $simLib
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    }
    # Separate library: this bench supplies behavioral SD and vendor FIFO models.
    $rtl = @('media_display_control','media_player_control','media_policy',
        'key_gesture_control', 'key_press_debounce', 'mode_key_control','dual_key_event_router','sd_card_bmp',
        'frame_fifo_read','frame_fifo_write','frame_read_write','bmp_header_check','bmp24_decoder','bmp_read') |
        ForEach-Object { "user_source/hdl_source/SD/$_.v" }
    & "$simTools/vlog.exe" -work $simLib -sv @rtl diagnostics/sd_recovery/tb_rescan_handoff.sv
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    foreach ($scenario in @(@(17,2), @(19,16), @(23,64))) {
        $pixelHalf = $scenario[0]
        $sourceGap = $scenario[1]
        $mode = 'handoff'
        $testLog = Join-Path $simDir "v052_rescan_${pixelHalf}_${sourceGap}.log"
        & "$simTools/vsim.exe" -c -quiet -voptargs=+acc -lib $simLib tb_rescan_handoff "-gPIX_HALF=$pixelHalf" "-gSOURCE_GAP=$sourceGap" -l $testLog -do 'run -all; quit -f'
        $result = Get-Content -LiteralPath $testLog -Raw
        if ($LASTEXITCODE -ne 0 -or $result -match '\*\* (Fatal|Error):' -or
            $result -notmatch 'PASS rescan real BMP' -or
            $result -notmatch 'Errors: 0, Warnings: 0') { throw "Handoff test failed: $testLog" }
    }
} finally { Pop-Location }
