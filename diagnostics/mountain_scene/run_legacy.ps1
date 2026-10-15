param(
 [ValidateSet('decoder','scaler','reader','reader32','preview','system','rgba_system','hazard_system','pcm','audit')][string]$Suite,
 [string]$RunName='mountain_m1',
 [string]$SimRoot='F:/modelsim/win64',
 [string]$TdRoot='E:/TD',
 [int[]]$Cases=@(),[int]$ByteGap=2,[int]$TestMode=0,[int]$ScaleTest=0,
 [int]$Mixed=1,[switch]$Audio,[switch]$Failures
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$paths=@{decoder='bmp_decoder/run_sim.ps1';scaler='media_adjust/run_scaler.ps1';reader='fat32/run_reader.ps1';preview='image_scaling/run_preview.ps1';system='image_scaling/run_system.ps1';rgba_system='image_scaling/run_system.ps1';pcm='pcm_audio/run_production.ps1';audit='four_bank/audit_timing.ps1'}
$paths['reader32']=$paths['reader']
$paths['hazard_system']=$paths['rgba_system']
# Reuse the established compile/test matrices, substituting only local tool and output paths.
$script=Get-Content (Join-Path "$root/diagnostics" $paths[$Suite]) -Raw
$script=$script.Replace('D:/modelsim/win64',$SimRoot).Replace('D:/TD/anlogic/TD6.2.1',$TdRoot)
$script=$script.Replace('$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ''../..''))', ('$root='''+$root.Replace('\','/')+''''))
$script=$script.Replace('"$root/diagnostics/output/bmp24_decoder_s1"',('"$root/diagnostics/output/'+$RunName+'"'))
$script=$script.Replace('& python diagnostics/fat32/generate_core_fixtures.py','& py -I diagnostics/fat32/generate_core_fixtures.py')
if($Suite -eq 'reader32'){
 $script=$script.Replace('diagnostics/fat32/generate_core_fixtures.py','diagnostics/mountain_scene/make_fixtures32.py').Replace('"-gSCALE_TEST=$ScaleTest"','"-gSCALE_TEST=$ScaleTest" -gRGBA_TEST=1')
}
# Intel 10.5 reports optional unconnected IP ports at vsim rather than vopt.
# Keep original transcripts and reject every warning outside these known classes.
$script=$script.Replace('Errors: 0, Warnings: 0','Errors: 0,').Replace('(Fatal|Error|Warning)','(Fatal|Error)')
$script=$script.Replace("vopt-(2685|2718|2121)","(vopt-(2685|2718|2121)|vsim-(3017|3722)|Design size of .*recommended capacity)")
if($Suite -in @('rgba_system','hazard_system')){
 $script=$script.Replace('../diagnostics/four_bank/tb_cache_system.sv','../diagnostics/mountain_scene/tb_rgba_sdram.sv').Replace('tb_cache_system','tb_rgba_sdram')
 $script=$script.Replace('+define+OSD_S1+OSD_S2+OSD_S3+OSD_UART+OSD_TIMESTAMP+TRANSITION_S1+PCM_S3','+define+M1_RGBA')
 $script=$script.Replace('-gSCALE_TEST=1','-gSCALE_TEST=1 -gMIXED_TEST=1')
 foreach($line in @(" if(`$log -notmatch 'PASS S2 origin:'", " if(`$log -notmatch 'Timestamp system observations:'", " if(`$log -notmatch 'PCM system observations:'")){
  $script=($script -split "`n" | Where-Object {!$_.StartsWith($line)}) -join "`n"
 }
}
if($Suite -eq 'hazard_system'){
 $script=$script.Replace('tb_rgba_sdram','tb_hazard_sdram')
 $script=$script.Replace('../diagnostics/mountain_scene/tb_hazard_sdram.sv','../user_source/hdl_source/scene/hazard_layer.v ../user_source/hdl_source/scene/scene_demo_timing.v ../diagnostics/mountain_scene/tb_hazard_sdram.sv')
}
$block=[scriptblock]::Create($script)
switch($Suite){
 decoder { & $block }
 reader { & $block -RunName $RunName -Cases $Cases -ByteGap $ByteGap -TestMode $TestMode -ScaleTest $ScaleTest }
 reader32 { & $block -RunName $RunName -Cases $Cases -ByteGap $ByteGap -TestMode $TestMode -ScaleTest $ScaleTest }
 preview { & $block -RunName $RunName -Mixed $Mixed -Audio:$Audio -Failures:$Failures }
 pcm { & $block -RunName $RunName -Tests @('tb_pcm_production','tb_pcm_preview_rescan') }
 audit { & $block -BuildName $RunName }
 default { & $block -RunName $RunName }
}
if($Suite -ne 'audit'){
 foreach($file in Get-ChildItem "$root/diagnostics/output/$RunName/*.log"){
  if($file.Name -match 'compile|library|console'){continue}
  $unexpected=@(Get-Content $file | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121)|vsim-(3017|3722)|Design size of .*recommended capacity)'})
  if($unexpected.Count){throw "Unexpected warnings in $file : $unexpected"}
 }
}
