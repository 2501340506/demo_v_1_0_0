param([string]$Name = 'io_timing_attempt1', [string]$TdRoot = 'D:/TD/anlogic/TD6.2.1', [ValidateSet('high','ultra')][string]$PostPlace = 'high', [int]$Seed = 0)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = Join-Path $root "diagnostics/output/$Name"
if (Test-Path $out) { throw "Choose a new build name: $out" }
New-Item -ItemType Directory -Path "$out/TD_project", "$out/diagnostics" -Force | Out-Null
Copy-Item -LiteralPath "$root/user_source" -Destination "$out/user_source" -Recurse
Copy-Item -LiteralPath "$root/TD_project/demo.al" -Destination "$out/TD_project/demo.al"
Copy-Item -LiteralPath "$root/diagnostics/run_td_build.ps1" -Destination "$out/diagnostics/run_td_build.ps1"
if ($Seed -ne 0) {
    $runner = Get-Content "$out/diagnostics/run_td_build.ps1" -Raw
    $runner = $runner.Replace('$physicalOptions = @()', ('$physicalOptions = @(''place seed ' + $Seed + ''')'))
    [IO.File]::WriteAllText("$out/diagnostics/run_td_build.ps1",$runner,[Text.UTF8Encoding]::new($false))
}
& "$out/diagnostics/run_td_build.ps1" -BuildName $Name -TdRoot $TdRoot -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization $PostPlace
$report = Join-Path $out 'audit'
New-Item -ItemType Directory -Path $report | Out-Null
Push-Location $report
try {
    $portable = $out.Replace('\','/')
    $analysis = (Join-Path $PSScriptRoot 'analyze.tcl').Replace('\','/')
    $wrapper = "set project {$portable/TD_project/demo_Runs/phy_1/demo.prj}`nset database {$portable/TD_project/demo_Runs/phy_1/demo_pr.db}`nset constraints {$portable/user_source/constraints_source/timing.sdc}`nsource {$analysis}`n"
    [IO.File]::WriteAllText((Join-Path $report 'run.tcl'),$wrapper,[Text.UTF8Encoding]::new($false))
    & "$TdRoot/bin/td_commands_prompt.exe" run.tcl *> analyze.log
    if ($LASTEXITCODE -ne 0 -or !(Test-Path exceptions.timing)) { throw 'Timing audit failed' }
    $clockLines = Get-Content "$out/user_source/constraints_source/timing.sdc" | Where-Object { $_ -match '^create_(generated_)?clock ' }
    [IO.File]::WriteAllLines((Join-Path $report 'clocks.sdc'),$clockLines,[Text.UTF8Encoding]::new($false))
    $edgeScript = (Join-Path $PSScriptRoot 'measure_edges.tcl').Replace('\','/')
    $edgeWrapper = "set project {$portable/TD_project/demo_Runs/phy_1/demo.prj}`nset database {$portable/TD_project/demo_Runs/phy_1/demo_pr.db}`nset clock_sdc {$portable/audit/clocks.sdc}`nsource {$edgeScript}`n"
    [IO.File]::WriteAllText((Join-Path $report 'edges.tcl'),$edgeWrapper,[Text.UTF8Encoding]::new($false))
    & "$TdRoot/bin/td_commands_prompt.exe" edges.tcl *> edges.log
    if ($LASTEXITCODE -ne 0 -or !(Test-Path hdmi_edges.timing)) { throw 'Edge report failed' }
    python "$PSScriptRoot/audit_nodes.py" check_timing.txt routed.v nodes.md
    if ($LASTEXITCODE -ne 0) { throw 'Unexplained dummy pin' }
    python "$PSScriptRoot/check_reports.py" $report
    if ($LASTEXITCODE -ne 0) { throw 'Timing acceptance failed' }
} finally { Pop-Location }
Write-Output "Evidence: $out"
