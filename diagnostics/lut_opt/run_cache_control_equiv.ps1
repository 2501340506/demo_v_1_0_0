param([string]$RunName='lut_opt_b6_cache1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
# Splice a v0.15.0 instance into the existing bench and compare every output every cycle.
$bench=Get-Content "$root/diagnostics/four_bank/tb_frame_cache_control.sv" -Raw
$outputs=@('scan_request','scan_result_ready','scan_busy','request_ready','foreground_busy','load_request','load_image','load_bank',
 'load_result_ready','cancel_request','storage_busy','storage_stopped','display_request','display_image','display_bank','display_valid',
 'current_image','current_bank','first_image_committed','committed_valid','committed_image','image_count','cache_valid','cache_failed',
 'cache_banks','cache_complete','cache_hit','request_failed','load_failed','retry_event','cache_complete_image','cache_hit_image','failed_image')
$ports=($outputs | ForEach-Object {".$_(ref_$_)"}) -join ','
$decl=(@('scan_request','scan_result_ready','scan_busy','request_ready','foreground_busy','load_request','load_result_ready','cancel_request',
 'storage_busy','storage_stopped','display_request','display_valid','first_image_committed','committed_valid','cache_complete','cache_hit',
 'request_failed','load_failed','retry_event') | ForEach-Object {" wire ref_$_;"}) -join ''
$decl+=(@('load_image','load_bank','display_image','display_bank','current_image','current_bank','committed_image','cache_complete_image',
 'cache_hit_image','failed_image') | ForEach-Object {" wire [1:0] ref_$_;"}) -join ''
$decl+=' wire [2:0] ref_image_count; wire [3:0] ref_cache_valid, ref_cache_failed; wire [7:0] ref_cache_banks;'
$lhs=($outputs | ForEach-Object {"dut.$_"}) -join ','
$rhs=($outputs | ForEach-Object {"ref_$_"}) -join ','
$inst="`n$decl`n media_frame_cache_control_v015 reference_dut (.*,$ports);`n integer equiv_cycles=0;`n always @(negedge clk) begin equiv_cycles=equiv_cycles+1; if({$lhs}!=={$rhs}) `$fatal(1,`"cache control equivalence mismatch cycle=%0d`",equiv_cycles); end`n final `$display(`"PASS cache control cycle equivalence cycles=%0d`",equiv_cycles);`n"
$anchor='    media_frame_cache_control dut (.*);'
if(-not $bench.Contains($anchor)){throw 'Bench anchor missing'}
$bench=$bench.Replace($anchor,"$anchor$inst")
[IO.File]::WriteAllText("$out/bench.sv",$bench)
$sim='d:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/media_frame_cache_control.v" "$root/user_source/hdl_source/SD/media_player_control.v" "$PSScriptRoot/media_frame_cache_control_v015.v" "$out/bench.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw "Compile failed: $out/compile.log"}
Push-Location $out
try{
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_frame_cache_control -l "$out/sim.log" -do 'run -all; quit -f' *> "$out/console.log"
 $log=Get-Content "$out/sim.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS cache control cycle equivalence' -or $log -match '\*\* (Fatal|Error)'){throw "Test failed: $out/sim.log"}
 Write-Output "PASS cache control equivalence"
}finally{Pop-Location}
