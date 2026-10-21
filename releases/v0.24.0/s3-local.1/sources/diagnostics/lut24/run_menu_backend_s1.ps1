param([string]$RunName='lut24_s1_backend1',[int]$Cycles=2000000)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$backend="$root/user_source/hdl_source/scene/disaster_menu_backend.v"
$support=@("$PSScriptRoot/disaster_menu_backend_reference.v","$PSScriptRoot/tb_menu_backend_s1_equivalence.sv")
function Run-Case([string]$name,[string]$dut,[bool]$expectPass,[int]$seed,[int]$contract){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib $dut @support *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_menu_backend_s1_equivalence "-gSEED=$seed" "-gCYCLES=$Cycles" "-gPARENT_CONTRACT=$contract" -l "$dir/sim.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/sim.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS backend') -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 $cov=([regex]::Match($log,'COVERAGE[^\r\n]*')).Value
 if($expectPass -and -not $pass){throw "Test failed: $dir/sim.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name $cov"}else{Write-Output "DETECTED $name"}
}
foreach($seed in @(5,17,23)){Run-Case "equiv_seed$seed" $backend $true $seed 1}
# The removed parent compare is only redundant under the production contract.
Run-Case 'contract_violation' $backend $false 5 0
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $backend -Raw
$mutants=@(
 @('confirm_source','else begin directory<=selected_directory;','else begin directory<=saved_directory;'),
 @('scene_source','directory<=clusters[scene*32+:32];hazard<=','directory<=parent_cluster;hazard<='),
 @('invalidate_keep','if(invalidate)begin cache_complete<=0;valid<=0;end','if(invalidate)begin valid<=0;end')
)
foreach($m in $mutants){
 if(!$text.Contains($m[1])){throw "Mutant anchor missing: $($m[0])"}
 $path="$mut/$($m[0]).v"
 [IO.File]::WriteAllText($path,$text.Replace($m[1],$m[2]))
 Run-Case "mutant_$($m[0])" $path $false 5 1
}
