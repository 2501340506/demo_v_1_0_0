param([string]$RunName='four_bank_s1_paths')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
$sim='D:/modelsim/win64'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$lib=(Join-Path $out 'work').Replace('\','/')
Push-Location "$root/TD_project"
try {
 if(!(Test-Path "$lib/_info")){& "$sim/vlib.exe" $lib;if($LASTEXITCODE){throw 'vlib failed'}}
 # Only the wrapper gets SIMULATION; protected IP keeps production latency.
 & "$sim/vlog.exe" -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v *> "$out/controller_compile.log"
 if($LASTEXITCODE){throw 'controller compile failed'}
 & "$sim/vlog.exe" -sv +define+SIMULATION -work $lib '+incdir+../user_source/hdl_source/include' ../user_source/hdl_source/SD/sdram.v *> "$out/wrapper_compile.log"
 if($LASTEXITCODE){throw 'wrapper compile failed'}
 $rtl=@('media_frame_loader','media_frame_reader','frame_fifo_read','frame_fifo_write','color_bar','video_timing_data','video_delay') | ForEach-Object {"../user_source/hdl_source/SD/$_.v"}
 & "$sim/vlog.exe" -sv -work $lib @rtl ../user_source/hdl_source/IP/afifo_16_32_256.v ../user_source/hdl_source/IP/afifo_32_16_256.v ../diagnostics/single_pll/sdram_bl4_model.sv ../diagnostics/four_bank/tb_frame_paths.sv *> "$out/compile.log"
 if($LASTEXITCODE){throw "RTL/bench compile failed: $out/compile.log"}
 & "$sim/vsim.exe" -c -quiet -lib $lib tb_frame_paths -l "$out/paths.log" -do 'run -all; quit -f' *> "$out/console.log"
 $rc=$LASTEXITCODE;$log=Get-Content "$out/paths.log" -Raw
 if($rc -ne 0 -or $log -match '\*\* (Fatal|Error):' -or $log -notmatch 'PASS frame paths:' -or $log -notmatch 'Errors: 0,'){throw "Frame paths failed: $out/paths.log"}
 # Vendor FIFO omitted optional ports and protected-IP unsized constants are
 # existing warnings; retain them in evidence, reject other warning classes.
 $unexpected=@($log -split "`n" | Where-Object {$_ -match '\*\* Warning:' -and $_ -notmatch 'vopt-(2685|2718|2121)'})
 if($unexpected.Count){throw "Unexpected ModelSim warning: $unexpected"}
 Write-Output "PASS production SDRAM frame paths: $out/paths.log"
}finally{Pop-Location}
