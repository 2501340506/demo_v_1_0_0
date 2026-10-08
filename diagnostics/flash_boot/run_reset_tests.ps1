param([switch]$BaselineTop, [ValidateSet('reset','startup')][string]$Suite='reset', [switch]$BypassReady)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$simTools = 'D:/modelsim/win64'
$simDir = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../output'))) $(if ($BaselineTop) { 'flash_boot_s1_negative' } elseif ($BypassReady) { 'flash_boot_startup_negative' } else { "flash_boot_${Suite}" })
$lib = (Join-Path $simDir 'reset_work').Replace('\','/')
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
Push-Location $repoRoot
try {
    if (-not (Test-Path "$lib/_info")) {
        & "$simTools/vlib.exe" $lib
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    }
    [xml]$project = (Get-Content TD_project/demo.al -Raw).Replace('UsedInP&R','UsedInP&amp;R')
    $modeled = @('sys_pll_s3.v','sys_pll.v','video_pll.v','sdram.v','afifo_16_32_256.v','afifo_32_16_256.v',
        'sdr_as_ram.enc.v','sdr_init_ref.enc.v','sdr_wrrd.enc.v')
    $rtl = @($project.SelectNodes('/Project/Source_Files/Verilog/File') | ForEach-Object {
        $path = $_.GetAttribute('Path')
        if ((Split-Path $path -Leaf) -notin $modeled) { Join-Path "$repoRoot/TD_project" $path }
    })
    # The user GUI project may predate UART. Include current production UART
    # sources without editing that project; explicit paths avoid duplicate files.
    foreach ($uart in @('uart_tx_byte.v','uart_boot_reporter.v','uart_event_logger.v')) {
        if (-not ($rtl | Where-Object { (Split-Path $_ -Leaf) -eq $uart })) {
            $rtl += Join-Path $repoRoot "user_source/hdl_source/uart/$uart"
        }
    }
    if (-not ($rtl | Where-Object { (Split-Path $_ -Leaf) -eq 'bmp24_decoder.v' })) {
        $rtl += Join-Path $repoRoot 'user_source/hdl_source/SD/bmp24_decoder.v'
    }
    if (-not ($rtl | Where-Object { (Split-Path $_ -Leaf) -eq 'bmp_header_check.v' })) {
        $rtl += Join-Path $repoRoot 'user_source/hdl_source/SD/bmp_header_check.v'
    }
    if ($BaselineTop) {
        # Negative control: the new test must reject the old constant-reset top.
        $oldTop = Join-Path $simDir 'top_before_s1.v'
        $source = (& git show 'v0.5.0-plan.1:user_source/hdl_source/top_tf_hdmi_audio.v') -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read S0 top' }
        [IO.File]::WriteAllText($oldTop, $source, [Text.UTF8Encoding]::new($false))
        $rtl = @($rtl | Where-Object { (Split-Path $_ -Leaf) -ne 'top_tf_hdmi_audio.v' }) + @($oldTop)
    }
    $topDefines = @()
    if ($BaselineTop) { $topDefines += '+define+PRE_UART_TOP' }
    & "$simTools/vlog.exe" -sv -work $lib @topDefines '+incdir+user_source/hdl_source/SD' -l "$simDir/compile.log" @rtl `
        D:/TD/anlogic/TD6.2.1/sim_release/eg4/eg_logic_io.v D:/TD/anlogic/TD6.2.1/sim_release/eg4/eg_phy_glbl.v diagnostics/flash_boot/tb_flash_reset.sv diagnostics/flash_boot/tb_startup.sv
    if ($LASTEXITCODE -ne 0) { throw 'reset top compile failed' }
    $test = if ($Suite -eq 'startup') { 'tb_startup' } else { 'tb_flash_reset' }
    $pass = if ($Suite -eq 'startup') { 'PASS FLASH S2' } else { 'PASS FLASH S1' }
    $simArgs = @()
    if ($BypassReady) { $simArgs += '+BYPASS_READY' }
    & "$simTools/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $test glbl @simArgs -l "$simDir/reset.log" -do 'run -all; quit -f'
    $log = Get-Content "$simDir/reset.log" -Raw
    if ($BypassReady) {
        if ($log -notmatch 'scan before both initialization completions' -or $log -match 'PASS FLASH S2') {
            throw 'Readiness negative control did not fail at the intended startup gate'
        }
        Write-Output 'PASS negative control: bypassed memory readiness rejected'
    } elseif ($BaselineTop) {
        if ($log -notmatch 'button must reach both PLL resets and discard locks' -or $log -match 'PASS FLASH S1') {
            throw 'Negative control did not fail at the intended PLL reset check'
        }
        Write-Output 'PASS negative control: old top rejected for unconnected PLL reset'
    } elseif ($LASTEXITCODE -ne 0 -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch $pass -or $log -notmatch 'Errors: 0, Warnings: 0') {
        throw 'reset top simulation failed'
    }
} finally { Pop-Location }
