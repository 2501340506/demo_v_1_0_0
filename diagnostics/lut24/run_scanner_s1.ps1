param([string]$RunName='lut24_s1_scanner1',[int]$Scans=400)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$scanner="$root/user_source/hdl_source/SD/fat32_volume_scanner.v"
$support=@("$root/user_source/hdl_source/SD/fat32_lfn_directories.v","$PSScriptRoot/fat32_volume_scanner_reference.v","$PSScriptRoot/tb_scanner_s1_equivalence.sv")
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
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_scanner_s1_equivalence "-gDIRECTORY_ENABLE=$($cfg[0])" "-gREUSE_GEOMETRY=$($cfg[1])" "-gSCAN_AUDIO=$($cfg[2])" "-gSCAN_TEXT=$($cfg[3])" "-gSCAN_PUBLICITY=$($cfg[4])" "-gSEED=$seed" "-gSCANS=$Scans" -l "$dir/sim.log" -do 'run -all; quit -f' *> "$dir/console.log"
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
# Mutants: last MBR match wins; mirror check ignores FAT count; root offset uses one shift too few.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $scanner -Raw
$mutants=@(
 @('mbr_last',"mbr_take<=!mbr_found && (sector_byte==8'h0b","mbr_take<=(sector_byte==8'h0b"),
 @('mirror_count',"(sector_byte[3:1]==0 && (fat_two || !sector_byte[0]))","(sector_byte[3:1]==0)"),
 @('root_offset',"ROOT:begin overhead<=current_cluster-2;shift_count<=cluster_shift;","ROOT:begin overhead<=current_cluster-2;shift_count<=cluster_shift-(cluster_shift!=0);")
)
foreach($m in $mutants){
 if(!$text.Contains($m[1])){throw "Mutant anchor missing: $($m[0])"}
 $path="$mut/$($m[0]).v"
 [IO.File]::WriteAllText($path,$text.Replace($m[1],$m[2]))
 Run-Case "mutant_$($m[0])" $path $false $configs[0] 11
}
