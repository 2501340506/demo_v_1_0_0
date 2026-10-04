$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$simTools = 'D:/modelsim/win64'
$vendor = 'D:/TD/anlogic/TD6.2.1/sim_release/eg4'
$simDir = Join-Path $PSScriptRoot 'modelsim_hdmi_r2_s6'
$lib = (Join-Path $simDir 's6_work').Replace('\','/')
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
Push-Location $repoRoot
try {
    if (-not (Test-Path "$lib/_info")) {
        & "$simTools/vlib.exe" $lib
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    }
    $rtl = @(Get-ChildItem user_source/hdl_source/hdmi_audio -Filter '*.v' | ForEach-Object {$_.FullName})
    & "$simTools/vlog.exe" -sv -work $lib '+incdir+user_source/hdl_source/SD' -l "$simDir/compile.log" @rtl `
        user_source/hdl_source/audio/pcm_test_tone.v user_source/hdl_source/SD/color_bar.v `
        user_source/hdl_source/SD/video_timing_data.v user_source/hdl_source/SD/video_delay.v `
        user_source/hdl_source/hdmi_phy_warpper.v user_source/hdl_source/lane_lvds_10_1.v `
        "$vendor/eg_logic_io.v" "$vendor/eg_phy_glbl.v" diagnostics/tb_hdmi_packets.sv diagnostics/tb_hdmi_s6_phy.sv
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    Push-Location $simDir
    try {
        foreach ($test in @('tb_hdmi_packets','tb_hdmi_s6_phy')) {
            $simOptions = @()
            if ($test -eq 'tb_hdmi_packets') { $simOptions += '-gSILENCE=1' }
            & "$simTools/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $test glbl @simOptions -l "$simDir/$test.log" -do 'run -all; quit -f'
            $log = Get-Content "$simDir/$test.log" -Raw
            if ($LASTEXITCODE -ne 0 -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0') {
                throw "S6 simulation failed: $test"
            }
        }
        & python -X utf8 "$repoRoot/diagnostics/check_hdmi_packets.py" tone_packets.txt
        if ($LASTEXITCODE -ne 0) { throw 'S6 packet reference failed' }
        $nonzero = Get-Content tone_packets.txt | Where-Object { $_ -like 'A *' -and $_ -ne 'A 0000 0000' }
        if ($nonzero) { throw 'S6 PCM is not silent' }
        Write-Output 'PASS S6 all accepted and decoded PCM samples are zero'
    } finally { Pop-Location }
} finally { Pop-Location }
