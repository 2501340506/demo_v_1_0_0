param([Parameter(Mandatory=$true)][string]$BuildName,[string]$TdRoot='E:/TD')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName/timing_audit"
$run=(Join-Path $root "diagnostics/output/$BuildName/TD_project/demo_Runs/phy_1").Replace('\','/')
if(Test-Path $out){throw 'Audit output already exists'}
if(!(Test-Path "$run/demo.bit")){throw 'Complete TD build first'}
New-Item -ItemType Directory $out | Out-Null
$script=@"
import_device eagle_s20.db -package EG4S20BG256
open_project {$run/demo.prj} -noanalyze
import_db {$run/demo_pr.db}
update_timing -mode final
check_timing -verbose -file check_timing.txt
report_timing_summary -file audit.timing
exit
"@
[IO.File]::WriteAllText("$out/audit.tcl",$script,[Text.UTF8Encoding]::new($false))
Push-Location $out
try{
 & "$TdRoot/bin/td_commands_prompt.exe" "$($out.Replace('\','/'))/audit.tcl" *> "$out/console.log"
 if($LASTEXITCODE -or !(Test-Path "$out/check_timing.txt")){throw 'Timing audit failed'}
 Write-Output "Timing audit: $out/check_timing.txt"
}finally{Pop-Location}
