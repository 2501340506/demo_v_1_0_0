param([Parameter(Mandatory=$true)][string]$OutputDirectory)
# Local Windows System.Speech. No cloud service, recording, or voice imitation.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Speech
$destination=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $destination){throw 'Use a NEW output directory'}
[IO.Directory]::CreateDirectory($destination) | Out-Null
$speaker=[System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
 $speaker.SelectVoice('Microsoft Huihui Desktop')
 $speaker.Rate=-1
 $speaker.Volume=100
 $format=[System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(48000,
  [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
  [System.Speech.AudioFormat.AudioChannel]::Mono)
 foreach($slot in 1..4){
  $script=[IO.File]::ReadAllText((Join-Path $PSScriptRoot "scripts/page$slot.txt"),[Text.Encoding]::UTF8).Trim()
  $speaker.SetOutputToWaveFile((Join-Path $destination "narration$slot.wav"),$format)
  $speaker.Speak($script)
  $speaker.SetOutputToNull()
 }
 $record=[ordered]@{engine='Windows System.Speech / SAPI'; voice=$speaker.Voice.Name;
  culture=$speaker.Voice.Culture.Name; rate=-1; volume=100; sample_rate=48000;
  channels=1; bits=16; status='synthetic_narration_pending_full_listening_review';
  provenance='Generated from scripts/page1-4.txt; no human voice recording or imitation';
  reproduction='Freeze WAV inputs; engine output across machines is not guaranteed byte-identical'}
 [IO.File]::WriteAllText((Join-Path $destination 'voice.json'),
  ($record | ConvertTo-Json -Depth 4)+"`n",[Text.UTF8Encoding]::new($false))
}finally{$speaker.Dispose()}
