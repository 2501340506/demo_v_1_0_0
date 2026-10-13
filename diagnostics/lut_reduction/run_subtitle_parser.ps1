param([string]$RunName='lut_subtitle_parser1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/uart/subtitle_uart_controller.v" "$PSScriptRoot/subtitle_uart_controller_ref.v" "$PSScriptRoot/tb_subtitle_parser_equiv.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_subtitle_parser_equiv -l "$out/tb_subtitle_parser_equiv.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/tb_subtitle_parser_equiv.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS ' -or $log -match '\*\* (Fatal|Error|Warning)'){throw "Test failed: $out/tb_subtitle_parser_equiv.log"}
 Write-Output "PASS tb_subtitle_parser_equiv"
}finally{Pop-Location}
