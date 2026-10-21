param([string]$RunName='lut24_s1_panel_layer1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$src="$root/user_source/hdl_source"
$almap='d:/TD/anlogic/TD6.2.1/sim_release/common/al_map_lut.v'
function Run-Case([string]$name,[string]$top,[string[]]$files,[string[]]$params,[string]$passText,[bool]$expectPass){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib @files *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib $top @params -l "$dir/sim.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/sim.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match $passText) -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 $cov=([regex]::Match($log,'COVERAGE[^\r\n]*')).Value
 if($expectPass -and -not $pass){throw "Test failed: $dir/sim.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name $cov"}else{Write-Output "DETECTED $name"}
}
$panel="$src/SD/seg7_panel.v"
$segFiles=@("$src/SD/seg_scan.v","$src/SD/seg_decoder.v","$PSScriptRoot/seg7_panel_reference.v","$PSScriptRoot/tb_seg_page_s1.sv")
foreach($seed in @(3,19)){Run-Case "seg_page_seed$seed" 'tb_seg_page_s1' (@($panel)+$segFiles) @("-gSEED=$seed") 'PASS seg page' $true}
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $panel -Raw
$anchor="debug_page<=debug_page+1'b1"
if(!$text.Contains($anchor)){throw 'Mutant anchor missing: panel page'}
[IO.File]::WriteAllText("$mut/seg7_panel_page.v",$text.Replace($anchor,"debug_page<=debug_page+2'd2"))
Run-Case 'mutant_panel_page' 'tb_seg_page_s1' (@("$mut/seg7_panel_page.v")+$segFiles) @('-gSEED=3') 'PASS seg page' $false

$layerFiles=@($almap,"$src/scene/hazard_layer.v","$src/scene/hazard_layer_v3.v","$src/scene/disaster_layer.v","$src/adjust/brightness_contrast_adjust.v","$PSScriptRoot/disaster_layer_reference.v","$PSScriptRoot/tb_layer_side_s1.sv")
foreach($seed in @(7,31)){Run-Case "layer_side_seed$seed" 'tb_layer_side_s1' $layerFiles @("-gSEED=$seed") 'PASS layer side' $true}
Run-Case 'mutant_layer_slice' 'tb_layer_side_s1' $layerFiles @('-gSEED=7','-gDESC_LSB=7') 'PASS layer side' $false
