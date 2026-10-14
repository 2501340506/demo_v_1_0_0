param([string]$RunName='lut_opt_b4_equiv1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$hdmi="$root/user_source/hdl_source/hdmi_audio"
function Run-Equiv([string]$name,[string]$packetizer,[bool]$expectPass){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib "$hdmi/hdmi_bch8.v" $packetizer "$PSScriptRoot/hdmi_audio_sample_packetizer_v015.v" "$PSScriptRoot/tb_batch4_equiv.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_batch4_equiv -l "$dir/tb_batch4_equiv.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/tb_batch4_equiv.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS ') -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/tb_batch4_equiv.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name"}else{Write-Output "DETECTED $name"}
}
$new="$hdmi/hdmi_audio_sample_packetizer.v"
Run-Equiv 'equiv' $new $true
# Mutants: channel status in the wrong packet; ECC lane order swapped.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$cases=@(@('status',"(next_audio_frame_base == 8'd32)","(next_audio_frame_base == 8'd28)"),
         @('lanes','pending_ecc1, pending_ecc0}','pending_ecc0, pending_ecc1}'))
foreach($c in $cases){
 $text=Get-Content $new -Raw
 if(-not $text.Contains($c[1])){throw "Mutation anchor missing: $($c[0])"}
 $m="$mut/$($c[0]).v"; $text.Replace($c[1],$c[2]) | Set-Content $m -NoNewline
 Run-Equiv ("mutant_"+$c[0]) $m $false
}
