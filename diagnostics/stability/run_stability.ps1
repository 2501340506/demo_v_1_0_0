param([ValidateSet('baseline','recovery','headers')][string]$Suite='baseline')
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$simTools='D:/modelsim/win64'
$outDir=Join-Path $repoRoot "diagnostics/output/stability_$Suite"
$lib=(Join-Path $outDir 'work').Replace('\','/')
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Push-Location $repoRoot
try {
    if (-not (Test-Path "$lib/_info")) { & "$simTools/vlib.exe" $lib }
    $rtl=@('bmp_read')
    $test='tb_bmp_baseline'
    if ($Suite -eq 'headers') { $test='tb_bmp_headers' }
    if ($Suite -eq 'recovery') {
        $rtl+=@('sd_card_bmp','media_display_control','media_player_control','mode_key_control',
            'key_press_debounce','sd_card_top','sd_card_sec_read_write','sd_card_cmd','spi_master')
        $test='tb_bmp_recovery'
    }
    $files=@($rtl | ForEach-Object { "user_source/hdl_source/SD/$_.v" })
    & "$simTools/vlog.exe" -sv -work $lib -l "$outDir/compile.log" @files diagnostics/stability/sim_bmp_sectors.sv "diagnostics/stability/$test.sv"
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    & "$simTools/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $test -l "$outDir/test.log" -do 'run -all; quit -f'
    $result=Get-Content "$outDir/test.log" -Raw
    if ($LASTEXITCODE -ne 0 -or $result -match '\*\* (Fatal|Error):' -or $result -notmatch 'PASS ' -or $result -notmatch 'Errors: 0, Warnings: 0') { throw "$Suite failed" }
} finally { Pop-Location }
