$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root 'diagnostics/output/fat32_sector'
$lib="$out/work".Replace('\','/')
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Force $out | Out-Null
Push-Location $root
try {
    if(!(Test-Path "$lib/_info")){& "$sim/vlib.exe" $lib}
    $rtl=@('sd_sector_adapter','sd_card_top','sd_card_sec_read_write','sd_card_cmd','spi_master') | ForEach-Object { "user_source/hdl_source/SD/$_.v" }
    $rtl=@('D:/TD/anlogic/TD6.2.1/arch/al_lmacro.v')+$rtl
    & "$sim/vlog.exe" -sv -work $lib -l "$out/compile.log" @rtl diagnostics/fat32/tb_sd_sector_adapter.sv diagnostics/fat32/tb_sd_sector_driver.sv
    if($LASTEXITCODE){throw 'sector compilation failed'}
    & "$sim/vsim.exe" -c -quiet -lib $lib tb_sd_sector_adapter -l "$out/test.log" -do 'run -all; quit -f'
    $result=Get-Content "$out/test.log" -Raw
    if($LASTEXITCODE -or $result -match '\*\* (Fatal|Error)' -or $result -notmatch 'PASS sector adapter all scenarios' -or $result -notmatch 'Errors: 0, Warnings: 0'){throw 'sector tests failed'}
    & "$sim/vsim.exe" -c -quiet -voptargs=+acc -lib $lib tb_sd_sector_driver -l "$out/driver.log" -do 'run -all; quit -f'
    $result=Get-Content "$out/driver.log" -Raw
    if($LASTEXITCODE -or $result -match '\*\* (Fatal|Error)' -or $result -notmatch 'PASS sector real driver all scenarios' -or $result -notmatch 'Errors: 0, Warnings: 0'){throw 'sector real driver tests failed'}
} finally {Pop-Location}
