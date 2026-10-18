param([string]$RunName='bottom_wave_integration01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose fresh RunName'}
New-Item -ItemType Directory $out | Out-Null
$original=Get-Content "$root/diagnostics/osd/tb_runtime_pixels.sv" -Raw
foreach($layout in @('legacy','publicity')){
 $bench=$original.Replace('tb_runtime_pixels',"tb_layout_$layout").Replace('.RUNTIME_ENABLE(1)', '.ALT_LAYOUT_ENABLE(1),.RUNTIME_ENABLE(1)').Replace('.clk(clk)',(".alternate_layout(1'b"+$(if($layout -eq 'publicity'){'1'}else{'0'})+"),.clk(clk)"))
 if($layout -eq 'publicity'){$bench=$bench.Replace('y>=439 && y<=465','y>=419 && y<=465').Replace('row=y-444','row=y-424').Replace('y>=440 && y<464','y>=420 && y<444')}
 [IO.File]::WriteAllText("$out/tb_layout_$layout.sv",$bench)
}
Copy-Item "$root/diagnostics/osd/cn_reference_rows.hex" "$out/cn_reference_rows.hex"
$sim='F:/modelsim/win64';$lib="$out/work"
& "$sim/vlib.exe" $lib *> "$out/library.log"
$vendor=Get-ChildItem 'E:/TD/sim_release/eg4/*.v','E:/TD/sim_release/common/*.v' | ForEach-Object {$_.FullName}
& "$sim/vlog.exe" -work $lib @vendor *> "$out/vendor.log"
if($LASTEXITCODE){throw 'vendor compile'}
Push-Location "$root/TD_project"
try {
 [xml]$project=(Get-Content demo.al -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | Where-Object {!$_.SelectSingleNode("FileInfo/Attr[@Name='AutoExcluded' and @Val='true']")} | ForEach-Object {$_.GetAttribute('Path')})
 $enc=@($rtl | Where-Object {$_ -like '*.enc.v'})
 $plain=@($rtl | Where-Object {$_ -notlike '*.enc.v' -and $_ -notlike '*sys_pll_s3.v'})
 & "$sim/vlog.exe" -work $lib '../user_source/ip_source/s3_single_pll/sys_pll_s3.v' *> "$out/pll.log"
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' @enc *> "$out/encrypted.log"
 if($LASTEXITCODE){throw 'encrypted compile'}
 & "$sim/vlog.exe" -sv '+define+SIMULATION' -work $lib '+incdir+../user_source/hdl_source/include' @plain "$root/diagnostics/single_pll/sdram_bl4_model.sv" "$PSScriptRoot/tb_wave_top.sv" "$out/tb_layout_legacy.sv" "$out/tb_layout_publicity.sv" *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile failed'}
}finally{Pop-Location}
Push-Location $out
try{
 foreach($name in @('tb_wave_top','tb_layout_legacy','tb_layout_publicity')){
  & "$sim/vsim.exe" -c -quiet -lib $lib $name glbl -l "$out/$name.log" -do 'run -all; quit -f' *> "$out/$name.console.log"
  $log=Get-Content "$out/$name.log" -Raw
  if($LASTEXITCODE -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS '){throw "FAIL $name"}
  $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121))' -and !($_ -match '(vopt-2241|vsim-3015)' -and $_ -match 'sys_pll_s3.v\(89\)' -and $_ -match 'load_reg')})
  if($unexpected.Count){throw "Unexpected warnings $name : $unexpected"}
  Write-Output "PASS $name"
 }
}finally{Pop-Location}
