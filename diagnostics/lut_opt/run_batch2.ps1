param([string]$RunName='lut_opt_b2_equiv1')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
if(Test-Path $out){throw 'Choose a new RunName'}
New-Item -ItemType Directory -Path $out | Out-Null
$sim='d:/modelsim/win64';$td='d:/TD/anlogic/TD6.2.1/sim_release'
[xml]$project=(Get-Content "$root/TD_project/demo.al" -Raw).Replace('UsedInP&R','UsedInP&amp;R')
$modeled=@('sys_pll_s3.v','sys_pll.v','video_pll.v','sdram.v','sdr_as_ram.enc.v','sdr_init_ref.enc.v','sdr_wrrd.enc.v')
$rtl=@($project.SelectNodes('/Project/Source_Files/Verilog/File') | ForEach-Object {
 $p=$_.GetAttribute('Path');if((Split-Path $p -Leaf) -notin $modeled){[IO.Path]::GetFullPath((Join-Path "$root/TD_project" $p))}
})
$refs=@('frame_fifo_write_v015.v','frame_fifo_read_v015.v','media_frame_reader_v015.v','thumbnail_address_v015.v') | ForEach-Object {"$PSScriptRoot/$_"}
function Run-Equiv([string]$name,[string[]]$files,[bool]$expectPass){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib "+incdir+$root/user_source/hdl_source/SD" "+incdir+$root/user_source/hdl_source/include" @files @refs "$td/common/al_map_lut.v" "$td/eg4/eg_logic_io.v" "$td/eg4/eg_phy_glbl.v" "$PSScriptRoot/tb_batch2_equiv.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_batch2_equiv glbl -l "$dir/tb_batch2_equiv.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/tb_batch2_equiv.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS ') -and ($log -notmatch '\*\* (Fatal|Error)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/tb_batch2_equiv.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name"}else{Write-Output "DETECTED $name"}
}
Run-Equiv 'equiv' $rtl $true
# Mutants: one extra burst per frame; wrong preview base for bank 1; reader one burst short.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$cases=@(
 @('frame_fifo_write.v','write_cnt < write_len[ADDR_BITS - 1:BURST_LOG2]','write_cnt <= write_len[ADDR_BITS - 1:BURST_LOG2]'),
 @('thumbnail_address.v',"3'b101:base=21'd1305600","3'b101:base=21'd1305664"),
 @('frame_fifo_read.v','read_cnt < read_len_round[ADDR_BITS:BURST_LOG2]','read_cnt + 1 < read_len_round[ADDR_BITS:BURST_LOG2]'))
foreach($c in $cases){
 $orig=$rtl | Where-Object {(Split-Path $_ -Leaf) -eq $c[0]}
 $text=Get-Content $orig -Raw
 if(-not $text.Contains($c[1])){throw "Mutation anchor missing in $($c[0])"}
 $m="$mut/$($c[0])"; $text.Replace($c[1],$c[2]) | Set-Content $m -NoNewline
 Run-Equiv ("mutant_"+[IO.Path]::GetFileNameWithoutExtension($c[0])) (@($rtl | Where-Object {$_ -ne $orig})+$m) $false
}
