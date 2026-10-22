param([string]$RunName='lut25_narration1')
# v0.25 S3: AUTO waits for the stage's narration. Lockstep against the frozen
# v0.24 scenario_fsm, the directed cases, and mutants that must be detected.
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64'
$src="$root/user_source/hdl_source/scene/scenario_fsm.v"
function Run-One([string]$name,[string]$dutFile,[string]$top,[bool]$expectPass,[string]$marker){
 $dir="$out/$name"; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work"
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib $dutFile "$PSScriptRoot/scenario_fsm_v024.v" "$PSScriptRoot/tb_narration_gate.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib $top -l "$dir/tb.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/tb.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match $marker) -and ($log -notmatch '\*\* (Fatal|Error)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/tb.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name $(([regex]"$marker[^\r\n]*").Match($log).Value)"}else{Write-Output "DETECTED $name"}
}
Run-One 'lockstep' $src 'tb_narration_lockstep' $true 'PASS narration lockstep'
Run-One 'directed' $src 'tb_narration_directed' $true 'PASS narration directed'
$mut="$out/mutant_src"; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $src -Raw
function Mutant([string]$name,[string]$from,[string]$to,[string]$top,[string]$marker){
 if(-not $text.Contains($from)){throw "Mutant $name pattern missing"}
 $text.Replace($from,$to) | Set-Content "$mut/$name.v" -NoNewline
 Run-One "mut_$name" "$mut/$name.v" $top $false $marker
}
# The hold ignored (two benches); inverted. Gating only the state transition
# and not the sample-counter's copy of the AUTO term is behaviourally equal:
# AUTO needs t=239, where the counter is idle and the next state change clears it.
Mutant 'ignored' '&& !(NARRATION_GATE && narration_hold);' ';' 'tb_narration_directed' 'PASS narration directed'
Mutant 'ignored_lock' '&& !(NARRATION_GATE && narration_hold);' ';' 'tb_narration_lockstep' 'PASS narration lockstep'
Mutant 'inverted' '&& !(NARRATION_GATE && narration_hold);' '&& (NARRATION_GATE && narration_hold);' 'tb_narration_directed' 'PASS narration directed'
Mutant 'warn_blocked' 'if(key_mode || (!warn_mode && (key_next || auto_go)))begin' 'if(key_mode || (key_next || auto_go))begin' 'tb_narration_lockstep' 'PASS narration lockstep'
