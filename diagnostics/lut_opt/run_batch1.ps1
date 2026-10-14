param([string]$RunName='lut_opt_b1_equiv1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64'
$src="$root/user_source/hdl_source"
function Run-Equiv([string]$name,[string[]]$files,[bool]$expectPass){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib @files "$PSScriptRoot/brightness_contrast_adjust_v015.v" "$PSScriptRoot/pcm_media_tone_v015.v" "$PSScriptRoot/tb_batch1_equiv.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_batch1_equiv -l "$dir/tb_batch1_equiv.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/tb_batch1_equiv.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS ') -and ($log -notmatch '\*\* (Fatal|Error|Warning)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/tb_batch1_equiv.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name"}else{Write-Output "DETECTED $name"}
}
$tone="$src/audio/pcm_media_tone.v"; $adjust="$src/adjust/brightness_contrast_adjust.v"
Run-Equiv 'equiv' @($adjust,$tone) $true
# Mutants: wrong negative rounding in the tone table; saturation window one bit too narrow.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
(Get-Content $tone -Raw).Replace('S2N = (-8485 * FV) >>> 8','S2N = -((8485 * FV) >>> 8)') | Set-Content "$mut/tone_m.v" -NoNewline
(Get-Content $adjust -Raw).Replace("product[17:14]==4'b0000","product[17:13]==5'b00000") | Set-Content "$mut/adjust_m.v" -NoNewline
Run-Equiv 'mutant_tone' @($adjust,"$mut/tone_m.v") $false
Run-Equiv 'mutant_adjust' @("$mut/adjust_m.v",$tone) $false
