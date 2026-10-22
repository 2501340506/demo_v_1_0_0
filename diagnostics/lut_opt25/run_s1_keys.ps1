param([string]$RunName='lut25_keys1')
# v0.25 S1 batch 1: mode_key_control on the shared 1 ms tick against the
# frozen v0.24.0 module. One clock per ms must match on every clock; 20 clocks
# per ms must match every edge within one tick. Three configurations
# (publicity, scene-only, legacy), three seeds, plus mutants that must be
# detected.
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).Replace('\','/')
$out="$root/diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64'
$src="$root/user_source/hdl_source/SD/mode_key_control.v"
$deb="$root/user_source/hdl_source/SD/key_press_debounce.v"
function Run-Keys([string]$name,[string]$dutFile,[bool]$expectPass,[string[]]$extra){
 $dir="$out/$name"; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work"
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib $dutFile $deb "$PSScriptRoot/mode_key_control_v024.v" "$PSScriptRoot/tb_keys_tick.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_keys_tick @extra -l "$dir/tb.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/tb.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS ') -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/tb.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name $(([regex]'PASS [^\r\n]*').Match($log).Value)"}else{Write-Output "DETECTED $name"}
}
$configs=@{pub=@('-gPUB=1','-gSCENE=1');scene=@('-gPUB=0','-gSCENE=1');legacy=@('-gPUB=0','-gSCENE=0')}
foreach($c in 'pub','scene','legacy'){
 Run-Keys "exact_$c" $src $true (@('-gF=1000','-gGESTURES=200','-gSEED=25')+$configs[$c])
 foreach($seed in 25,7,3){Run-Keys "tick_${c}_seed$seed" $src $true (@('-gF=20000',"-gSEED=$seed")+$configs[$c])}
}
# Mutants: no tick correction; debounce one tick short; KEY4 adjust long press
# at 300 ms; scene/application long press at 300 ms.
$mut="$out/mutant_src"; New-Item -ItemType Directory -Path $mut | Out-Null
$text=Get-Content $src -Raw
function Mutant([string]$name,[string]$from,[string]$to){
 if(-not $text.Contains($from)){throw "Mutant $name pattern missing"}
 $text.Replace($from,$to) | Set-Content "$mut/$name.v" -NoNewline
 Run-Keys "mut_$name" "$mut/$name.v" $false (@('-gF=20000','-gSEED=25')+$configs['pub'])
}
Mutant 'no_adjust' 'localparam integer TICK_ADJ = MS_CYCLES > 1 ? 1 : 0;' 'localparam integer TICK_ADJ = 0;'
Mutant 'debounce' 'if (cnt >= DEBOUNCE_MS - 1) begin' 'if (cnt >= DEBOUNCE_MS - 2) begin'
Mutant 'adjust_long4' 'localparam LONG=1000+TICK_ADJ;' 'localparam LONG=300+TICK_ADJ;'
Mutant 'long_ticks' 'localparam integer LONG_TICKS = 1000 + 2*TICK_ADJ;' 'localparam integer LONG_TICKS = 300 + 2*TICK_ADJ;'
