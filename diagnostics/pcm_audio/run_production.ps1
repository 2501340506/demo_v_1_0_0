param([string]$RunName='pcm_s3_production1',[string[]]$Tests=@('tb_pcm_production'))
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
if($LASTEXITCODE){throw 'vlib failed'}
Push-Location $root
try {
 [xml]$project=(Get-Content TD_project/demo.al -Encoding UTF8 -Raw).Replace('UsedInP&R','UsedInP&amp;R')
 $modeled=@('sys_pll_s3.v','sys_pll.v','video_pll.v','sdram.v','afifo_16_32_256.v','afifo_32_16_256.v','sdr_as_ram.enc.v','sdr_init_ref.enc.v','sdr_wrrd.enc.v')
 $rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | ForEach-Object {
  $p=$_.GetAttribute('Path');if((Split-Path $p -Leaf) -notin $modeled){Join-Path "$root/TD_project" $p}
 })
 $benches=@($Tests | ForEach-Object {"diagnostics/pcm_audio/$_.sv"})
 & "$sim/vlog.exe" -sv -work $lib @rtl @benches D:/TD/anlogic/TD6.2.1/sim_release/common/al_map_lut.v *> "$out/compile.log"
 if($LASTEXITCODE){throw 'compile failed'}
 foreach($test in $Tests){
  & "$sim/vsim.exe" -c -quiet -lib $lib $test -l "$out/$test.log" -do 'run -all; quit -f' *> "$out/$test.console.log"
  $rc=$LASTEXITCODE;$x=Get-Content "$out/$test.log" -Raw
  if($rc -or $x -notmatch 'PASS ' -or $x -match '\*\* (Fatal|Error|Warning)' -or $x -notmatch 'Errors: 0, Warnings: 0'){throw "Test failed: $out/$test.log"}
  Write-Output "PASS $test"
 }
}finally{Pop-Location}
