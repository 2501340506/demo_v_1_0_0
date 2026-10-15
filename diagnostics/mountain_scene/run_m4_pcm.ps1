param([string]$RunName='mountain_m4_scenario_pcm01')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script=Get-Content "$root/diagnostics/pcm_audio/run_production.ps1" -Raw
$script=$script.Replace('D:/modelsim/win64','F:/modelsim/win64').Replace('D:/TD/anlogic/TD6.2.1','E:/TD')
$script=$script.Replace('$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ''../..''))', ('$root='''+$root.Replace('\','/')+''''))
$script=$script.Replace('diagnostics/pcm_audio/$_.sv','diagnostics/mountain_scene/$_.sv')
$script=$script.Replace('Errors: 0, Warnings: 0','Errors: 0,').Replace('(Fatal|Error|Warning)','(Fatal|Error)')
& ([scriptblock]::Create($script)) -RunName $RunName -Tests @('tb_scenario_pcm')
$log=Get-Content "$root/diagnostics/output/$RunName/tb_scenario_pcm.log" -Raw
if($log -notmatch 'PASS M6 actual PCM'){throw 'Missing integration PASS'}
$unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch '(vopt-(2685|2718|2121)|vsim-(3017|3722))'})
if($unexpected.Count){throw "Unexpected warnings: $unexpected"}
