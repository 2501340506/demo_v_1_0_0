param([string]$Stage='s0')
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$outDir=Join-Path $repoRoot "diagnostics/output/stability_$Stage/regression"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$tests=@('run_control_tests','run_mode_tests','run_buffer_handoff','run_audio_tests',
    'run_hdmi_packet_tests','run_video_alignment','run_hdmi_s6_tests','run_s9_reset_tests')
foreach ($test in $tests) {
    $script=Join-Path $repoRoot "diagnostics/history/v0.3.0/$test.ps1"
    if ($Stage -ne 's0' -and $test -in @('run_control_tests','run_buffer_handoff')) {
        $script=Join-Path $PSScriptRoot "$test.ps1"
    }
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script)
    if ($test -eq 'run_hdmi_s6_tests') { $arguments+=@('-Stage','s9') }
    & powershell @arguments *> (Join-Path $outDir "$test.log")
    if ($LASTEXITCODE -ne 0) { throw "$test failed; see $outDir" }
    Write-Output "PASS $Stage $test"
}
