param([string[]]$Tests = @('tb_sd_protocol','tb_rescan_key','tb_sd_initialization','tb_sd_spi_pins','tb_sd_init_retry'),[string]$RunName='v052_sd_recovery')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = Join-Path $root "diagnostics/output/$RunName"
$sim = 'D:/modelsim/win64'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$lib = (Join-Path $out 'work').Replace('\','/')
Push-Location $root
try {
    if (-not (Test-Path "$lib/_info")) { & "$sim/vlib.exe" $lib }
    $rtl = @('sd_card_cmd','sd_card_sec_read_write','sd_card_top','spi_master','mode_key_control','key_press_debounce') | ForEach-Object { "user_source/hdl_source/SD/$_.v" }
    foreach ($test in $Tests) {
        & "$sim/vlog.exe" -sv -work $lib -l "$out/${test}_compile.log" @rtl "diagnostics/sd_recovery/$test.sv"
        if ($LASTEXITCODE -ne 0) { throw "Compile failed: $test" }
        & "$sim/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f'
        $log = Get-Content "$out/$test.log" -Raw
        if ($LASTEXITCODE -ne 0 -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0') { throw "Failed: $test" }
    }
} finally { Pop-Location }
