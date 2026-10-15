param([string]$RunName='mountain_m5_sd01',[string]$SimRoot='F:/modelsim/win64')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$old=(& git -C $root show 'v0.17.0-m4-local.1:user_source/hdl_source/SD/sd_card_cmd.v') -join "`n"
if($LASTEXITCODE -ne 0){throw 'Cannot read M4 reference'}
[IO.File]::WriteAllText("$out/sd_card_cmd_m4.v",$old.Replace('module sd_card_cmd #(','module sd_card_cmd_m4 #('),$utf8)
$lib="$out/work".Replace('\','/')
& "$SimRoot/vlib.exe" $lib
$rtl=@('sd_card_cmd','sd_card_sec_read_write','sd_card_top','spi_master','mode_key_control','key_press_debounce') | ForEach-Object {"$root/user_source/hdl_source/SD/$_.v"}
$tests=@('tb_sd_protocol','tb_sd_initialization','tb_sd_spi_pins','tb_sd_init_retry')
& "$SimRoot/vlog.exe" -sv -work $lib -l "$out/compile.log" E:/TD/sim_release/common/al_map_lut.v @rtl "$out/sd_card_cmd_m4.v" "$PSScriptRoot/tb_m5_sd_timeout.sv" @($tests | ForEach-Object {"$root/diagnostics/sd_recovery/$_.sv"})
if($LASTEXITCODE -ne 0){throw 'Compile failed'}
foreach($name in @('tb_m5_sd_timeout')+$tests){
 & "$SimRoot/vsim.exe" -c -quiet -voptargs=+acc -lib $lib $name -l "$out/$name.log" -do 'run -all; quit -f'
 $log=Get-Content "$out/$name.log" -Raw
 if($LASTEXITCODE -ne 0 -or $log -match '\*\* (Fatal|Error)' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Failed: $name"}
}
