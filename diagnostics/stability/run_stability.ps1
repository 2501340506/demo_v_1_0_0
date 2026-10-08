param([ValidateSet('baseline','recovery','headers','scan','pixels','timeout','timeout_control')][string]$Suite='baseline', [switch]$CompareS2)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$simTools='D:/modelsim/win64'
$outDir=Join-Path $repoRoot "diagnostics/output/stability_$Suite"
if ($CompareS2) {
    if ($Suite -ne 'scan') { throw 'CompareS2 is only valid for scan' }
    $outDir=Join-Path $repoRoot 'diagnostics/output/stability_scan_s2'
}
$lib=(Join-Path $outDir 'work').Replace('\','/')
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Push-Location $repoRoot
try {
    if (-not (Test-Path "$lib/_info")) { & "$simTools/vlib.exe" $lib }
    $rtl=@('bmp_header_check','bmp24_decoder','bmp_read')
    $test='tb_bmp_baseline'
    if ($Suite -eq 'headers') { $test='tb_bmp_headers' }
    if ($Suite -eq 'scan') { $test='tb_bmp_scan' }
    if ($Suite -eq 'pixels') { $test='tb_bmp_pixels' }
    if ($Suite -eq 'timeout') { $test='tb_bmp_timeout' }
    if ($Suite -in @('recovery','timeout_control')) {
        $rtl+=@('sd_card_bmp','media_display_control','media_player_control','mode_key_control',
            'key_press_debounce','sd_card_top','sd_card_sec_read_write','sd_card_cmd','spi_master')
        $test=if ($Suite -eq 'recovery') { 'tb_bmp_recovery' } else { 'tb_timeout_control' }
    }
    $files=@($rtl | ForEach-Object { "user_source/hdl_source/SD/$_.v" })
    if ($CompareS2) {
        $source=(& git show 'v0.4.0-s2-board.1:user_source/hdl_source/SD/bmp_read.v') -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read S2 baseline' }
        $oldFile=Join-Path $outDir 'bmp_read_s2.v'
        [IO.File]::WriteAllText($oldFile,$source,[Text.UTF8Encoding]::new($false))
        $files=@($oldFile)
    }
    $defines=@()
    if ($CompareS2) { $defines+= '+define+STABILITY_S2' }
    & "$simTools/vlog.exe" @defines -sv -work $lib -l "$outDir/compile.log" @files diagnostics/stability/sim_bmp_sectors.sv "diagnostics/stability/$test.sv"
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    $simArgs=@()
    if ($CompareS2) { $simArgs+= '-gBASELINE=1' }
    & "$simTools/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $test @simArgs -l "$outDir/test.log" -do 'run -all; quit -f'
    $result=Get-Content "$outDir/test.log" -Raw
    if ($LASTEXITCODE -ne 0 -or $result -match '\*\* (Fatal|Error):' -or $result -notmatch 'PASS ' -or $result -notmatch 'Errors: 0, Warnings: 0') { throw "$Suite failed" }
} finally { Pop-Location }
