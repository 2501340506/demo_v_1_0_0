# Manually run only with the identified 8 GB G: test card connected.
# Adds files; never formats, deletes, or overwrites existing files.
$ErrorActionPreference='Stop'
$root='G:\'
$folder=Join-Path $root 'FAT32_S3_TEST'
if(!(Test-Path (Join-Path $root 'PIC1.bmp'))){throw 'G:\PIC1.bmp is required'}
foreach($p in @($folder,(Join-Path $root 'PIC2.bmp'),(Join-Path $root 'PIC4.bmp'))){if(Test-Path -LiteralPath $p){throw "Already exists; nothing changed: $p"}}
foreach($i in 1..160){$p=Join-Path $root ('FT{0:D6}.TMP' -f $i);if(Test-Path -LiteralPath $p){throw "Already exists; nothing changed: $p"}}
New-Item -ItemType Directory -Path $folder | Out-Null
# Allocate actual written data, rather than relying on an unwritten file length.
$block=New-Object byte[] 1048576
$f=[IO.File]::Open((Join-Path $folder 'PAD128M.BIN'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{foreach($i in 1..128){$f.Write($block,0,$block.Length)};$f.Flush($true)}finally{$f.Dispose()}
# These short-name root entries exercise later directory sectors/clusters.
foreach($i in 1..160){$f=[IO.File]::Open((Join-Path $root ('FT{0:D6}.TMP' -f $i)),[IO.FileMode]::CreateNew);$f.Dispose()}
# Alternate allocation of one 4096-byte cluster between image and spacer.
# Actual fragmentation must be confirmed by inspect_test_card.py afterward.
$source=[IO.File]::ReadAllBytes((Join-Path $root 'PIC1.bmp'))
$chunk=New-Object byte[] 4096
$picture=$null;$spacer=$null
try{
 $picture=[IO.File]::Open((Join-Path $root 'PIC2.bmp'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 $spacer=[IO.File]::Open((Join-Path $folder 'SPACER.BIN'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 for($offset=0;$offset -lt $source.Length;$offset+=4096){
  $count=[Math]::Min(4096,$source.Length-$offset)
  $picture.Write($source,$offset,$count);$picture.Flush($true)
  $spacer.Write($chunk,0,$chunk.Length);$spacer.Flush($true)
 }
}finally{if($picture){$picture.Dispose()};if($spacer){$spacer.Dispose()}}
[IO.File]::Copy((Join-Path $root 'PIC3.bmp'),(Join-Path $root 'PIC4.bmp'),$false)
Write-Output 'Preparation finished. Keep the card in the PC for read-only FAT verification before board testing.'