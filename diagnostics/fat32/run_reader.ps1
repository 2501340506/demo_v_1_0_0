param([int[]]$Cases=@(),[int]$ByteGap=2,[int]$TestMode=0,[string]$RunName='fat32_core')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $root "diagnostics/output/$RunName"
$lib="$out/work".Replace('\','/')
$sim='D:/modelsim/win64'
Push-Location $root
try {
    & python diagnostics/fat32/generate_core_fixtures.py "$out/fixtures"
    if($LASTEXITCODE){throw 'fixture generation failed'}
    if(!(Test-Path "$lib/_info")){& "$sim/vlib.exe" $lib}
    $rtl=@('fat32_bmp_reader','sd_sector_adapter','fat32_volume_scanner','fat32_file_streamer','bmp_header_check','bmp24_decoder') | ForEach-Object { "user_source/hdl_source/SD/$_.v" }
    & "$sim/vlog.exe" -sv -work $lib -l "$out/compile.log" @rtl diagnostics/fat32/tb_fat32_reader.sv
    if($LASTEXITCODE){throw 'core compilation failed'}
    $manifest=Get-Content "$out/fixtures/manifest.json" -Raw | ConvertFrom-Json
    if($Cases.Count -eq 0){$Cases=@($manifest | ForEach-Object {$_.id})}
    foreach($id in $Cases){
        $log="$out/reader${id}_gap${ByteGap}_mode${TestMode}.log"
        & "$sim/vsim.exe" -c -quiet -lib $lib tb_fat32_reader "-gCASE_ID=$id" "-gBYTE_GAP=$ByteGap" "-gTEST_MODE=$TestMode" "-gFIXTURE_DIR=$($out.Replace('\','/'))/fixtures" -l $log -do 'run -all; quit -f' *> "$out/case${id}_console.log"
        $result=Get-Content $log -Raw
        if($LASTEXITCODE -or $result -match '\*\* (Fatal|Error)' -or $result -notmatch 'PASS FAT32 reader' -or $result -notmatch 'Errors: 0, Warnings: 0') {throw "core case $id failed; see $log"}
        Write-Output "PASS reader $id $($manifest[$id].name) gap=$ByteGap mode=$TestMode"
    }
} finally {Pop-Location}
