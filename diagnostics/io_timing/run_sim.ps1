$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = Join-Path $root 'diagnostics/output/io_timing_sim'
$sim = 'D:/modelsim/win64'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$lib = "$out/work".Replace('\','/')
if (!(Test-Path "$lib/_info")) { & "$sim/vlib.exe" $lib | Out-Null }
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/spi_master.v" "$PSScriptRoot/tb_spi_budget.sv" *> "$out/compile.log"
if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }
foreach ($case in @(@('slow',248,0,0),@('data',1,0,0),@('fast',1,0,1),@('old25',0,0,0),@('overbudget',1,1,0))) {
    $name,$div,$negative,$fast=$case
    $log="$out/$name.log"
    & "$sim/vsim.exe" -c -quiet -lib $lib tb_spi_budget "-gDIV=$div" "-gNEGATIVE=$negative" "-gFAST=$fast" -l $log -do 'run -all; quit -f' *> "$out/${name}_console.log"
    $text=Get-Content $log -Raw
    $expectFailure=$name -in @('old25','overbudget')
    if ($expectFailure) {
        if ($text -notmatch 'Fatal: byte mismatch') { throw "Negative control did not fail as expected: $name" }
        Write-Output "PASS expected rejection: $name"
    } elseif ($LASTEXITCODE -ne 0 -or $text -match '\*\* (Fatal|Error):' -or $text -notmatch 'PASS SPI budget') { throw "Failed: $name" }
    else { Write-Output "PASS $name" }
}
$rtl = @('sd_card_cmd','sd_card_sec_read_write','sd_card_top','spi_master') | ForEach-Object { "$root/user_source/hdl_source/SD/$_.v" }
& "$sim/vlog.exe" -sv -work $lib @rtl "$root/diagnostics/sd_recovery/tb_sd_spi_pins.sv" *> "$out/pins_compile.log"
if ($LASTEXITCODE -ne 0) { throw 'Pin integration compile failed' }
& "$sim/vsim.exe" -c -quiet -lib $lib tb_sd_spi_pins '-gOUT_DELAY=6.0' '-gMISO_DELAY=19.2' -l "$out/pins_delayed.log" -do 'run -all; quit -f' *> "$out/pins_console.log"
$result=Get-Content "$out/pins_delayed.log" -Raw
if ($LASTEXITCODE -ne 0 -or $result -match '\*\* (Fatal|Error):' -or $result -notmatch 'PASS pin-level CRC7' -or $result -notmatch 'Errors: 0, Warnings: 0') { throw 'Delayed pin integration failed' }
Write-Output 'PASS delayed pin-level initialization/CRC/recovery and card setup/hold'
