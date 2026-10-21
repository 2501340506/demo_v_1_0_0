param([string]$Script)
# Remaining arguments are passed to the script unchanged.
# Earlier sessions mounted ModelSim/TD under other volume names and used the
# py launcher. Run a path-adjusted temporary copy beside the original script
# so $PSScriptRoot is unchanged, then remove that single temporary file.
$ErrorActionPreference='Stop'
if(!$Script){throw "Script is required"}
$source=[IO.Path]::GetFullPath($Script)
$python=Join-Path $env:USERPROFILE 'scoop/apps/python/current/python.exe'
if(!(Test-Path $python)){throw "Python not found: $python"}
$text=[IO.File]::ReadAllText($source)
$text=$text.Replace('F:/modelsim','d:/modelsim')
$text=$text.Replace('E:/TD','d:/TD/anlogic/TD6.2.1')
$text=[regex]::Replace($text,'&\s*py\s',"& '$python' ")
$text=[regex]::Replace($text,'&\s*python\s',"& '$python' ")
$temp=Join-Path (Split-Path $source) ('_lut24_tmp_'+(Split-Path $source -Leaf))
[IO.File]::WriteAllText($temp,$text,[Text.UTF8Encoding]::new($true))
try{
 & powershell -NoProfile -ExecutionPolicy Bypass -File $temp @args
 $code=$LASTEXITCODE
}finally{Remove-Item -LiteralPath $temp}
exit $code
