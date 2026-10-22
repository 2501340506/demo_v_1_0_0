param([string]$RunName='adjust_panel1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$rtl=Get-ChildItem "$root/user_source/hdl_source/adjust/*.v" | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -sv -work $lib @rtl "$root/user_source/hdl_source/SD/mode_key_control.v" "$root/user_source/hdl_source/SD/key_press_debounce.v" "$root/user_source/hdl_source/osd/osd_pixel_position.v" "$root/user_source/hdl_source/osd/osd_font_5x7.v" "$PSScriptRoot/tb_adjust_panel.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try{
 foreach($test in @('tb_panel_keys','tb_panel_state','tb_panel_pixels','tb_panel_frame','tb_speed_request')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $log=Get-Content "$out/$test.log" -Raw
  if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error):'){throw "Test failed: $out/$test.log"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
