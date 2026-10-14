param([string]$RunName='lut_opt_b6_stream1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$new="$root/user_source/hdl_source/SD/fat32_file_streamer.v"
function Run-Txn([string]$name,[string]$streamer,[int]$gate,[bool]$expectPass){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib $streamer "$PSScriptRoot/fat32_file_streamer_v015.v" "$PSScriptRoot/tb_batch6_stream_txn.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_batch6_stream_txn "-gGATE=$gate" -l "$dir/sim.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/sim.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS ') -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/sim.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name"}else{Write-Output "DETECTED $name"}
}
Run-Txn 'gate0' $new 0 $true
Run-Txn 'gate1' $new 1 $true
# Mutant: one shift too few.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $new -Raw; $anchor='ST_SHIFT:if(shift_count!=0)'
if(-not $text.Contains($anchor)){throw 'Mutation anchor missing'}
$text.Replace($anchor,'ST_SHIFT:if(shift_count>1)') | Set-Content "$mut/streamer.v" -NoNewline
Run-Txn 'mutant_shift' "$mut/streamer.v" 0 $false
