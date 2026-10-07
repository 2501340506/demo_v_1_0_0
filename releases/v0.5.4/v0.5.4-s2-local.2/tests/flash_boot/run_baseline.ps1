param([string]$Stage = 's0')
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$outDir = Join-Path $repoRoot "diagnostics/output/flash_boot_$Stage"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Push-Location $repoRoot
try {
    foreach ($suite in @('baseline','recovery','headers','scan','pixels','timeout','timeout_control')) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite $suite *> "$outDir/$suite.log"
        if ($LASTEXITCODE -ne 0) { throw "Failed $suite; see $outDir" }
        Write-Output "PASS $suite"
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_pixel_handoff.ps1 *> "$outDir/pixel_handoff.log"
    if ($LASTEXITCODE -ne 0) { throw 'Pixel handoff failed' }
    Write-Output 'PASS pixel_handoff'
    # A non-s0 name selects the current stability control/buffer benches.
    & powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage "flash_boot_$Stage" *> "$outDir/regression.log"
    if ($LASTEXITCODE -ne 0) { throw 'Existing regression failed' }
    Copy-Item -LiteralPath "diagnostics/output/stability_flash_boot_$Stage/regression" -Destination "$outDir/regression" -Recurse
    Write-Output 'PASS eight existing regression entries'
} finally { Pop-Location }
