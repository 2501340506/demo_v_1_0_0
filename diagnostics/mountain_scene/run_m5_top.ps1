param([string]$RunName='mountain_m5_integration01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='F:/modelsim/win64';$lib="$out/work".Replace('\','/')
$bench='tb_m5_top'
$benchFile="$PSScriptRoot/tb_m5_top.sv"
$marker='PASS M5 production top'
& py -I "$PSScriptRoot/text_vectors.py" $out
$sizes=Get-Content "$out/sizes.json" -Raw | ConvertFrom-Json
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
 & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' @plain $benchFile *> "$out/compile.log"
 if($LASTEXITCODE){throw 'Top compile failed'}
 Push-Location $out
 try {
 & "$sim/vsim.exe" -c -quiet -lib $lib $bench glbl "+F_BYTES=$($sizes.font)" "+T_BYTES=$($sizes.text)" -l "$out/top.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/top.log" -Raw
 if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch $marker -or $log -notmatch 'Errors: 0,') {throw "Top test failed: $out/top.log"}
 $unexpected=@($log -split "`n" | Where-Object {
  $_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121)|vsim-(3017|3722))' -and
  !($_ -match '(vopt-2241|vsim-3015)' -and $_ -match 'sys_pll_s3.v\(89\)' -and $_ -match 'load_reg')
 })
 if($unexpected.Count){throw "Unexpected top warnings: $unexpected"}
 Write-Output 'PASS M5 production top resource pipeline'
 }finally{Pop-Location}
}finally{Pop-Location}
