param(
    [Parameter(Mandatory)][string]$DbPath,
    [Parameter(Mandatory)][string]$OutBit,
    # EG4 MSPI load clock; TD default (no -g) is 2.5MHz.
    [ValidateSet('2.5MHz','5MHz','7.5MHz','10MHz','12MHz','14.5MHz','16MHz','29MHz','36MHz')]
    [string]$MclkFreq = '16MHz',
    [string]$TdRoot = 'd:/TD/anlogic/TD6.2.1'
)
$ErrorActionPreference = 'Stop'
# Re-run only bitgen on a routed database; placement and routing are unchanged.
$db = (Resolve-Path -LiteralPath $DbPath).Path
$workDir = Split-Path $db -Parent
$outFull = [IO.Path]::GetFullPath($OutBit).Replace('\', '/')
$tclPath = Join-Path $workDir 'fast_boot_bitgen.tcl'
$logPath = Join-Path $workDir 'fast_boot_bitgen.log'
$tcl = @"
import_device eagle_s20.db -package EG4S20BG256
import_db {$($db.Replace('\', '/'))}
bitgen -bit {$outFull} -g {mclk_freq_div:$MclkFreq}
exit
"@
[IO.File]::WriteAllText($tclPath, $tcl, [Text.UTF8Encoding]::new($false))
Push-Location $workDir
try {
    # TD's Tcl treats backslashes as escapes.
    & "$TdRoot/bin/td_commands_prompt.exe" $tclPath.Replace('\', '/') *> $logPath
    if ($LASTEXITCODE -ne 0) { throw "TD bitgen failed: $logPath" }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -match '(?im)\bERROR:') { throw "TD bitgen reported errors: $logPath" }
    if ($log -notmatch 'Generate bitstream completely') { throw "No bitgen completion marker: $logPath" }
    Write-Output "PASS bitgen mclk_freq_div=$MclkFreq : $outFull"
} finally { Pop-Location }
