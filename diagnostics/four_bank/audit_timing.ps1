param([string]$BuildName='four_bank_s1_attempt2')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$BuildName/timing_audit"
$run=(Join-Path $root "diagnostics/output/$BuildName/TD_project/demo_Runs/phy_1").Replace('\','/')
New-Item -ItemType Directory -Path $out -Force | Out-Null
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
 & 'D:/TD/anlogic/TD6.2.1/bin/td_commands_prompt.exe' "$($out.Replace('\','/'))/audit.tcl" *> "$out/console.log"
 if($LASTEXITCODE){throw 'Timing audit failed'}
 if(!(Test-Path "$out/check_timing.txt")){throw 'No timing audit report'}
 Write-Output "Timing audit: $out/check_timing.txt"
}finally{Pop-Location}
