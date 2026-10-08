$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/bmp24_decoder_s1"
$lib="$out/work".Replace('\','/')
New-Item -ItemType Directory -Force $out | Out-Null
if(!(Test-Path "$lib/_info")){& D:/modelsim/win64/vlib.exe $lib}
Push-Location $root
try {
 & D:/modelsim/win64/vlog.exe -sv -work $lib -l "$out/compile.log" user_source/hdl_source/SD/bmp_header_check.v user_source/hdl_source/SD/bmp24_decoder.v diagnostics/stability/tb_bmp24_decoder.sv
 if($LASTEXITCODE){throw 'compile failed'}
 foreach($width in @(640,3)) {
  $height=if($width -eq 640){480}else{2}
  & D:/modelsim/win64/vsim.exe -c -quiet -lib $lib tb_bmp24_decoder "-gW=$width" "-gH=$height" -l "$out/matrix$width.log" -do 'run -all; quit -f'
  $log=Get-Content "$out/matrix$width.log" -Raw
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error)' -or $log -notmatch 'Errors: 0, Warnings: 0' -or ([regex]::Matches($log,'PASS decoder')).Count -ne 16){throw "matrix $width failed"}
 }
} finally {Pop-Location}
