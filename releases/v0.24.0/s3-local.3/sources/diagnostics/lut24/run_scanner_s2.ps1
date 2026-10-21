param([string]$RunName='lut24_s2_scanner1',[int]$Scans=400)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$scanner="$root/user_source/hdl_source/SD/fat32_volume_scanner.v"
$support=@("$root/user_source/hdl_source/SD/fat32_lfn_directories.v","$PSScriptRoot/fat32_volume_scanner_s1_reference.v","$PSScriptRoot/scanner_s1_indexed.v","$PSScriptRoot/tb_scanner_s2_equivalence.sv")
# DIRECTORY, REUSE, AUDIO, TEXT, PUBLICITY: production first, then legacy reader shapes.
$configs=@(@(1,1,1,1,1),@(1,0,1,1,1),@(0,0,1,1,0),@(0,0,0,0,0),@(0,1,1,0,1))
function Run-Case([string]$name,[string]$dut,[bool]$expectPass,[int[]]$cfg,[int]$seed){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib $dut @support *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_scanner_s2_equivalence "-gDIRECTORY_ENABLE=$($cfg[0])" "-gREUSE_GEOMETRY=$($cfg[1])" "-gSCAN_AUDIO=$($cfg[2])" "-gSCAN_TEXT=$($cfg[3])" "-gSCAN_PUBLICITY=$($cfg[4])" "-gSEED=$seed" "-gSCANS=$Scans" -l "$dir/sim.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/sim.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS scanner') -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 $cov=([regex]::Match($log,'COVERAGE[^\r\n]*')).Value
 if($expectPass -and -not $pass){throw "Test failed: $dir/sim.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name $cov"}else{Write-Output "DETECTED $name"}
}
$i=0
foreach($cfg in $configs){
 foreach($seed in @(11,29)){
  Run-Case ("equiv_cfg{0}_seed{1}" -f $i,$seed) $scanner $true $cfg $seed
 }
 $i++
}
# Mutants: thumb row aliases PIC1; VOI rows use the SND half; EDU rows overwrite the PIC rows.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $scanner -Raw
$mutants=@(
 @('thumb_row',"thumb_commit ? 4'd8 :","thumb_commit ? 4'd0 :"),
 @('voi_row',"{commit_voi,commit_snd,(commit_voi","{1'b0,commit_voi || commit_snd,(commit_voi"),
 @('edu_slot',"{1'b0,commit_edu,commit_index}","{2'b00,commit_index}")
)
foreach($m in $mutants){
 if(!$text.Contains($m[1])){throw "Mutant anchor missing: $($m[0])"}
 $path="$mut/$($m[0]).v"
 [IO.File]::WriteAllText($path,$text.Replace($m[1],$m[2]))
 Run-Case "mutant_$($m[0])" $path $false $configs[0] 11
}
