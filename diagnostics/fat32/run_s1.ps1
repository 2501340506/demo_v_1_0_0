$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root 'diagnostics/output/fat32_s1_suite'
New-Item -ItemType Directory -Force $out | Out-Null
$cases=@(
    @('sector','diagnostics/fat32/run_sector.ps1'),
    @('pixel','diagnostics/stability/run_pixel_handoff.ps1'),
    @('rescan','diagnostics/sd_recovery/run_handoff.ps1'),
    @('recovery','diagnostics/stability/run_stability.ps1','-Suite','recovery'),
    @('timeout','diagnostics/stability/run_stability.ps1','-Suite','timeout_control'),
    @('sd','diagnostics/sd_recovery/run_tests.ps1'),
    @('uart','diagnostics/uart_fastboot/run_sim.ps1','-RunName','fat32_s1_uart'),
    @('system','diagnostics/stability/run_regression.ps1','-Stage','fat32_s1_final'),
    @('startup','diagnostics/flash_boot/run_reset_tests.ps1','-Suite','startup')
)
foreach($case in $cases){
    $script=Join-Path $root $case[1]
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script)
    if($case.Count -gt 2){$arguments+=$case[2..($case.Count-1)]}
    & powershell @arguments *> "$out/$($case[0]).log"
    if($LASTEXITCODE){throw "Failed $($case[0]); see $out"}
    Write-Output "PASS FAT32 S1 $($case[0])"
}
