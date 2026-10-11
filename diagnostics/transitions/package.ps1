param([string]$BuildName='transition_s1_attempt1',[string]$Candidate='s1-local.1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& python "$PSScriptRoot/package.py" $BuildName $Candidate
if($LASTEXITCODE){throw 'Packaging failed'}
