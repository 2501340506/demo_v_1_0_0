param([string]$RunName='uart_reduction_options01',[string]$SimRoot='F:/modelsim/win64')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$lib="$out/work".Replace('\','/')
& "$SimRoot/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$SimRoot/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
Push-Location "$root/TD_project"
try {
 [xml]$project=(Get-Content demo.al -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path')})
 $enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
 $plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v'})
 & "$SimRoot/vlog.exe" -work $lib '../user_source/ip_source/s3_single_pll/sys_pll_s3.v' *> "$out/pll.log"
 if($LASTEXITCODE){throw 'PLL compile failed'}
 & "$SimRoot/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' @enc *> "$out/encrypted.log"
 if($LASTEXITCODE){throw 'Encrypted compile failed'}
 & "$SimRoot/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' @plain "$PSScriptRoot/tb_uart_options.sv" "$root/diagnostics/osd/tb_uart_subtitle.sv" "$root/diagnostics/uart_fastboot/tb_uart_event_logger.sv" *> "$out/compile.log"
 if($LASTEXITCODE){throw 'RTL compile failed'}
}finally{Pop-Location}
$cases=@(
 @{name='options00';tb='tb_uart_options';args=@('-gLOG=0','-gSUB=0')},
 @{name='options01';tb='tb_uart_options';args=@('-gLOG=0','-gSUB=1')},
 @{name='options10';tb='tb_uart_options';args=@('-gLOG=1','-gSUB=0')},
 @{name='options11';tb='tb_uart_options';args=@('-gLOG=1','-gSUB=1')},
 @{name='subtitle';tb='tb_uart_subtitle';args=@()},
 @{name='logger';tb='tb_uart_event_logger';args=@()})
Push-Location $out
try {
 foreach($case in $cases){
  $extra=$case.args
  & "$SimRoot/vsim.exe" -c -quiet -lib $lib $case.tb glbl @extra -l "$out/$($case.name).log" -do 'run -all; quit -f' *> "$out/$($case.name).console.log"
  $log=Get-Content -Raw "$out/$($case.name).log"
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0,'){throw "Failed $($case.name): $out"}
  $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121)|vsim-(3017|3722))' -and !($_ -match '(vopt-2241|vsim-3015)' -and $_ -match 'sys_pll_s3.v\(89\)' -and $_ -match 'load_reg')})
  if($unexpected.Count){throw "Unexpected warnings: $unexpected"}
  Write-Output "PASS $($case.name)"
 }
}finally{Pop-Location}
