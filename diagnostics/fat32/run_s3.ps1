$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root 'diagnostics/output/fat32_s3_suite'
New-Item -ItemType Directory -Force $out | Out-Null
$cases=@(
 @('reader','diagnostics/fat32/run_reader.ps1'),
 @('format_dimensions','diagnostics/fat32/run_reader.ps1','-Cases','0','-TestMode','1','-ByteGap','0'),
 @('format_32bit','diagnostics/fat32/run_reader.ps1','-Cases','0','-TestMode','2','-ByteGap','0'),
 @('format_length','diagnostics/fat32/run_reader.ps1','-Cases','0','-TestMode','3','-ByteGap','0'),
 @('ack_timeout','diagnostics/fat32/run_reader.ps1','-Cases','0','-TestMode','4','-ByteGap','0'),
 @('last_byte_end','diagnostics/fat32/run_reader.ps1','-Cases','0','-TestMode','5','-ByteGap','0'),
 @('recovery','diagnostics/stability/run_stability.ps1','-Suite','recovery'),
 @('timeout','diagnostics/stability/run_stability.ps1','-Suite','timeout_control'),
 @('pixel','diagnostics/stability/run_pixel_handoff.ps1'),
 @('rescan','diagnostics/sd_recovery/run_handoff.ps1'),
 @('system','diagnostics/stability/run_regression.ps1','-Stage','fat32_s3_final'),
 @('decoder','diagnostics/bmp_decoder/run_sim.ps1'),
 @('sd','diagnostics/sd_recovery/run_tests.ps1'),
 @('startup','diagnostics/flash_boot/run_reset_tests.ps1','-Suite','startup'),
 @('sector','diagnostics/fat32/run_sector.ps1'),
 @('uart','diagnostics/uart_fastboot/run_sim.ps1','-RunName','fat32_s3_uart_final')
)
foreach($case in $cases){
 $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $case[1]))
 if($case.Count -gt 2){$arguments+=$case[2..($case.Count-1)]}
 & powershell @arguments *> "$out/$($case[0]).log"
 if($LASTEXITCODE){throw "S3 failed $($case[0]); see $out"}
 Write-Output "PASS FAT32 S3 $($case[0])"
}
