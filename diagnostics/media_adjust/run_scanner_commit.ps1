param([string]$RunName='adjust_scanner_commit1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$reference=(& git -C $root show 'ebc494d:user_source/hdl_source/SD/fat32_volume_scanner.v') -join "`n"
if($LASTEXITCODE){throw 'Cannot read pre-change scanner'}
$reference=$reference -replace '\bmodule fat32_volume_scanner\b','module fat32_volume_scanner_reference'
[IO.File]::WriteAllText("$out/reference.v",$reference)
$bench=Get-Content "$root/diagnostics/pcm_audio/tb_audio_scan.sv" -Raw
$outputs=@('scan_busy','scan_done','fs_error','partition_lba','sectors_per_cluster','fat_start_lba','data_start_lba','max_cluster','resource_valid','resource0_cluster','resource1_cluster','resource2_cluster','resource3_cluster','resource0_size','resource1_size','resource2_size','resource3_size','audio_found','audio_cluster','audio_size','sector_req','sector_lba')
$instance=[regex]::Match($bench,'(?s) fat32_volume_scanner #.*?;').Value
$instance=$instance.Replace('fat32_volume_scanner #','fat32_volume_scanner_reference #').Replace(' dut(',' reference_dut(')
foreach($port in $outputs){$instance=[regex]::Replace($instance,"\.$port\([^)]*\)",".$port()")}
$lhs=($outputs | ForEach-Object {"dut.$_"}) -join ','
$rhs=($outputs | ForEach-Object {"reference_dut.$_"}) -join ','
$check="`n$instance`n always @(posedge clk) begin #1;if(!rst && {$lhs} !== {$rhs})`n `$fatal(1,`"scanner cycle equivalence mismatch scenario=%0d index=%0d`",scenario,idx);end`n"
$bench=$bench.Replace('endmodule',"$check`nendmodule")
[IO.File]::WriteAllText("$out/bench.sv",$bench)
$sim='D:/modelsim/win64';$lib="$out/work".Replace('\','/')
& "$sim/vlib.exe" $lib *> "$out/library.log"
& "$sim/vlog.exe" -sv -work $lib "$root/user_source/hdl_source/SD/fat32_volume_scanner.v" "$out/reference.v" "$out/bench.sv" *> "$out/compile.log"
if($LASTEXITCODE){throw 'Compile failed'}
Push-Location $out
try {
 foreach($gap in @(0,1,5)){
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_audio_scan "-gGAP=$gap" -l "$out/gap$gap.log" -do 'run -all; quit -f' *> "$out/gap$gap.console.log"
  $rc=$LASTEXITCODE;$log=Get-Content "$out/gap$gap.log" -Raw
  if($rc -or $log -match '\*\* (Fatal|Error|Warning):' -or $log -notmatch 'PASS ' -or $log -notmatch 'Errors: 0, Warnings: 0'){throw "Scanner test failed: gap$gap.log"}
  Write-Output "PASS scanner cycle equivalence GAP=$gap"
 }
}finally{Pop-Location}
