param([string]$BuildName='decoder_s2_attempt1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName"
if(Test-Path $out){throw 'Choose a new BuildName to preserve previous results'}
New-Item -ItemType Directory -Path "$out/TD_project","$out/diagnostics" -Force | Out-Null
Copy-Item "$root/user_source" "$out/user_source" -Recurse
$project=Get-Content "$root/releases/v0.5.3/v0.5.3-baseline/demo.al" -Encoding UTF8 -Raw
$entries=@'
            <File Path="../user_source/hdl_source/uart/uart_tx_byte.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="53"/></FileInfo></File>
            <File Path="../user_source/hdl_source/uart/uart_boot_reporter.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="54"/></FileInfo></File>
            <File Path="../user_source/hdl_source/uart/uart_event_logger.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="55"/></FileInfo></File>
'@
$entries += '<File Path="../user_source/hdl_source/SD/bmp24_decoder.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="56"/></FileInfo></File>'
$entries=$entries.Replace('UsedInP&amp;R','UsedInP&R')
$project=$project.Replace('</Verilog>',"$entries`n        </Verilog>")
[IO.File]::WriteAllText("$out/TD_project/demo.al",$project,[Text.UTF8Encoding]::new($false))
Copy-Item "$root/diagnostics/run_td_build.ps1" "$out/diagnostics/run_td_build.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$out/diagnostics/run_td_build.ps1" -BuildName $BuildName -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
if($LASTEXITCODE){throw 'TD build failed'}
