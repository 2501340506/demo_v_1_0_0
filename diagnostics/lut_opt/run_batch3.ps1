param([string]$RunName='lut_opt_b3_equiv1')
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
$refs=@('sd_card_cmd_v015.v','sd_card_sec_read_write_v015.v','pcm_stream_player_v015.v','fat32_pcm_stream_v015.v') | ForEach-Object {"$PSScriptRoot/$_"}
function Run-Equiv([string]$name,[string[]]$files,[bool]$expectPass){
 $dir=Join-Path $out $name; New-Item -ItemType Directory -Path $dir | Out-Null
 $lib="$dir/work".Replace('\','/')
 & "$sim/vlib.exe" $lib *> "$dir/library.log"
 & "$sim/vlog.exe" -sv -work $lib "+incdir+$root/user_source/hdl_source/SD" "+incdir+$root/user_source/hdl_source/include" @files @refs "$td/common/al_map_lut.v" "$td/eg4/eg_logic_io.v" "$td/eg4/eg_phy_glbl.v" "$PSScriptRoot/tb_batch3_equiv.sv" *> "$dir/compile.log"
 if($LASTEXITCODE){throw "Compile failed: $dir/compile.log"}
 Push-Location $dir
 try{
  & "$sim/vsim.exe" -c -quiet -lib $lib tb_batch3_equiv glbl -l "$dir/tb_batch3_equiv.log" -do 'run -all; quit -f' *> "$dir/console.log"
  $log=Get-Content "$dir/tb_batch3_equiv.log" -Raw
  $pass=(-not $LASTEXITCODE) -and ($log -match 'PASS ') -and ($log -notmatch '\*\* (Fatal|Error)')
 }finally{Pop-Location}
 if($expectPass -and -not $pass){throw "Test failed: $dir/tb_batch3_equiv.log"}
 if(-not $expectPass -and $pass){throw "Mutant not detected: $dir"}
 if($expectPass){Write-Output "PASS $name"}else{Write-Output "DETECTED $name"}
}
Run-Equiv 'equiv' $rtl $true
# Mutants: response counter one bit short; recovery wait ends early; phase step off by one; replay ends one byte early.
$mut=Join-Path $out 'mutant_src'; New-Item -ItemType Directory -Path $mut | Out-Null
$cases=@(
 @('sd_card_cmd.v','reg [$clog2(WAIT_MAX + 1) - 1:0] wait_count;','reg [$clog2(WAIT_MAX + 1) - 2:0] wait_count;'),
 @('sd_card_sec_read_write.v',"recover_count == 10'd1023","recover_count == 10'd1022"),
 @('pcm_stream_player.v','phase+RATE_SAMPLE-RATE_CLOCK :','phase+RATE_SAMPLE-RATE_CLOCK+1 :'),
 @('fat32_pcm_stream.v',"{1'b0,replay_offset}+1'b1>=size_latched[9:0]","{1'b0,replay_offset}+2'd2>=size_latched[9:0]"))
foreach($c in $cases){
 $orig=$rtl | Where-Object {(Split-Path $_ -Leaf) -eq $c[0]}
 $text=Get-Content $orig -Raw
 if(-not $text.Contains($c[1])){throw "Mutation anchor missing in $($c[0])"}
 $m="$mut/$($c[0])"; $text.Replace($c[1],$c[2]) | Set-Content $m -NoNewline
 Run-Equiv ("mutant_"+[IO.Path]::GetFileNameWithoutExtension($c[0])) (@($rtl | Where-Object {$_ -ne $orig})+$m) $false
}
