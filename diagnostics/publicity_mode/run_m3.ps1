param([string]$RunName='publicity_m3_attempt01',[switch]$CompileOnly)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'Vendor compile failed'}
Push-Location "$root/TD_project"
try {
 [xml]$project=(Get-Content demo.al -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path')})
 $enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
 $plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v'})
 & "$sim/vlog.exe" -work $lib '../user_source/ip_source/s3_single_pll/sys_pll_s3.v' *> "$out/pll.log"
 if($LASTEXITCODE){throw 'PLL compile failed'}
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' @enc *> "$out/encrypted.log"
 if($LASTEXITCODE){throw 'Encrypted compile failed'}
 $benches=@(Get-ChildItem "$PSScriptRoot/tb_m3_*.sv" | ForEach-Object {$_.FullName})
 & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' @plain @benches *> "$out/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $out"}
}finally{Pop-Location}
if($CompileOnly){Write-Output "PASS compile $out";exit}
function Run-Test([string]$top,[string]$name,[string[]]$params){
 & "$sim/vsim.exe" -c -quiet -lib $lib $top glbl @params -l "$out/$name.log" -do 'run -all; quit -f' *> "$out/$name.console.log"
 $log=Get-Content -Raw "$out/$name.log"
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS M3' -or $log -notmatch 'Errors: 0,'){throw "Failed $name : $out"}
 $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121)|vsim-(3017|3722))' -and !($_ -match '(vopt-2241|vsim-3015)' -and $_ -match 'sys_pll_s3.v\(89\)' -and $_ -match 'load_reg')})
 if($unexpected.Count){throw "Unexpected warnings $name : $unexpected"}
 Write-Output "PASS $name"
}
Run-Test tb_m3_keys 'keys' @()
Run-Test tb_m3_identity 'identity' @()
Run-Test tb_m3_stream_start 'streamer_start' @()
Run-Test tb_m3_stream_chain 'streamer_chain' @()
Run-Test tb_m3_scan_bounds 'scanner_bounds' @()
foreach($case in 0..9){Run-Test tb_m3_reload "reload_case$case" @("-gCARD_CASE=$case")}
Run-Test tb_m3_reload 'reload_scale' @('-gCARD_CASE=0','-gSCALE=1')
Run-Test tb_m3_reload 'reload_audio' @('-gCARD_CASE=0','-gAUDIO=1')
