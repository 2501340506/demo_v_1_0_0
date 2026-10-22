#!/usr/bin/env python3
"""Stage audio for scene cards: SND1-4.PCM, 48 kHz mono s16le.

Ported from the reference project's tools/scene_audio.py (v0.17 M4).
Each stage in scene.yaml may give
  sound: file          base track: any ffmpeg-readable file, or raw .PCM in
                       the board format (relative to scene.yaml)
  sound_gain: 0.3      optional base-track gain (default 1)
  sound_loop: true     optional: repeat the base track over the whole stage
  narration:           lines spoken at a time on the 0-239 t scale
    - {t: 0, text: ...}
    - {t: 65, text: ..., file: voice/line.wav}
A line starts at sample t*1600: on the board t advances once per 1600 played
samples at 1x, so the words line up with the picture's time t. A line that
would overlap the previous one is pushed back (reported). The track lasts at
least until t=239 plus 0.5 s. A line with `file:` (any ffmpeg-readable
recording, relative to scene.yaml) uses that recording; without it the
Windows SAPI zh-CN voice speaks `text` (tts=True), else a short beep marks
its start so the timing stays testable. Speech and recordings are trimmed to
20 ms around the voice and normalised alike, so the first word starts at the
line's t. A stage with neither sound nor narration gets no SND file: the FPGA
plays BGM.PCM for it.
"""
from pathlib import Path
import subprocess, sys, tempfile, wave
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))   # -I drops the script directory
from make_audio_corpus import convert  # noqa: E402

SAMPLE_HZ = 48000
SAMPLES_PER_T = 1600
T_END = 240

_SAPI = r'''
$text=[IO.File]::ReadAllText($args[0],[Text.Encoding]::UTF8)
Add-Type -AssemblyName System.Speech
$s=New-Object System.Speech.Synthesis.SpeechSynthesizer
$v=$s.GetInstalledVoices()|Where-Object{$_.VoiceInfo.Culture.Name -eq 'zh-CN'}|Select-Object -First 1
if(!$v){exit 3}
$s.SelectVoice($v.VoiceInfo.Name)
$s.Rate=2
$f=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(48000,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
$s.SetOutputToWaveFile($args[1],$f);$s.Speak($text);$s.Dispose()
'''


def read_wav48(path):
    with wave.open(str(path), 'rb') as w:
        if w.getframerate() != SAMPLE_HZ or w.getnchannels() != 1 or w.getsampwidth() != 2:
            raise SystemExit(f'{path}: expected 48 kHz mono 16-bit')
        return np.frombuffer(w.readframes(w.getnframes()), '<i2').copy()


def write_wav48(path, pcm):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SAMPLE_HZ)
        w.writeframes(pcm.astype('<i2').tobytes())


def speak(text, work):
    """SAPI zh-CN speech as int samples, or None when unavailable."""
    script = work / 'sapi.ps1'
    script.write_text(_SAPI, encoding='utf-8-sig')
    src, wav = work / 'line.txt', work / 'line.wav'
    src.write_text(text, encoding='utf-8')
    if wav.exists():
        wav.unlink()
    try:
        r = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script), str(src), str(wav)],
                           capture_output=True)
    except OSError:
        return None
    if r.returncode or not wav.exists():
        return None
    return shape(read_wav48(wav).astype(np.int32))


def decode(path, work):
    """Any audio file as int samples; raw .PCM is taken as the board format."""
    if not path.is_file():
        raise SystemExit(f'audio file not found: {path}')
    if path.suffix.lower() == '.pcm':
        return np.fromfile(path, '<i2').astype(np.int32)
    raw = work / 'decode.pcm'
    convert(path, raw, force=True)
    return np.fromfile(raw, '<i2').astype(np.int32)


def shape(pcm):
    # Speech engines pad each line with silence; keep 20 ms around the voice
    # so the first word starts at the line's t.
    loud = np.flatnonzero(np.abs(pcm) > 300)
    if loud.size:
        pad = SAMPLE_HZ // 50
        pcm = pcm[max(0, loud[0] - pad):loud[-1] + pad]
    peak = int(np.abs(pcm).max()) if pcm.size else 0
    if peak:   # normalise to about -1 dBFS
        pcm = pcm * 29000 // peak
    return pcm


def beep(n=int(0.15 * SAMPLE_HZ), hz=880):
    k = np.arange(n)
    env = np.minimum(1, np.minimum(k, n - k) / 240)
    return (np.sin(2 * np.pi * hz * k / SAMPLE_HZ) * env * 12000).astype(np.int32)


def stage_track(n, stage, base_dir, work, tts):
    """Stage n (0..3) as (int16 samples or None, notes, placements).
    placements: one dict per line with t, start sample, length and source."""
    sound, lines = stage.get('sound'), stage.get('narration') or []
    if not sound and not lines:
        return None, [], []
    notes, placements = [], []
    base = np.zeros(0, np.int32)
    if sound:
        base = decode(base_dir / sound, work)
        gain = float(stage.get('sound_gain', 1))
        if gain != 1:
            base = np.round(base * gain).astype(np.int32)
        notes.append(f'base {Path(sound).name} gain {gain:g}' + (' looped' if stage.get('sound_loop') else ''))
    placed, end = [], 0
    for line in sorted(lines, key=lambda d: d['t']):
        t = int(line['t'])
        if not 0 <= t < T_END:
            raise SystemExit(f'stage {n + 1}: narration t={t} outside 0..239')
        if line.get('file'):
            pcm = shape(decode(base_dir / line['file'], work))
            source = Path(line['file']).name
        else:
            pcm = speak(line['text'], work) if tts else None
            source = 'sapi'
        if pcm is None:
            pcm = beep()
            source = 'beep'
            notes.append(f't={t} beep')
        start = max(t * SAMPLES_PER_T, end)
        if start != t * SAMPLES_PER_T:
            notes.append(f't={t} pushed to t={start / SAMPLES_PER_T:.0f} after the previous line')
        placed.append((start, pcm))
        placements.append({'t': t, 'start': start, 'samples': len(pcm), 'source': source, 'text': str(line.get('text', ''))})
        end = start + len(pcm)
    loop = bool(stage.get('sound_loop')) and len(base)
    length = max(T_END * SAMPLES_PER_T + SAMPLE_HZ // 2, 0 if loop else len(base), end)
    if loop:
        base = np.resize(base, length)
    mix = np.zeros(length, np.int32)
    mix[:len(base)] += base
    for start, pcm in placed:
        mix[start:start + len(pcm)] += pcm
    if np.abs(mix).max() > 32767:
        notes.append(f'clipped {int(np.count_nonzero(np.abs(mix) > 32767))} samples')
    return np.clip(mix, -32768, 32767).astype('<i2'), notes, placements


def stage_tracks(cfg, base_dir, tts=False):
    """[(pcm or None, notes, placements)] for the four stages."""
    with tempfile.TemporaryDirectory() as tmp:
        return [stage_track(n, stage, Path(base_dir), Path(tmp), tts) for n, stage in enumerate(cfg['stages'])]


def write_stage_audio(cfg, base_dir, out, tts=True):
    """Write out/sd/SNDn.PCM and out/audio/SNDn.wav for the stages that have audio."""
    (out / 'audio').mkdir(parents=True, exist_ok=True)
    (out / 'sd').mkdir(parents=True, exist_ok=True)
    for n, (pcm, notes, _) in enumerate(stage_tracks(cfg, base_dir, tts)):
        pcm_path = out / 'sd' / f'SND{n + 1}.PCM'
        if pcm is None:
            if pcm_path.exists():
                pcm_path.unlink()
            print(f'stage {n + 1}: no audio, the board plays BGM.PCM')
            continue
        pcm_path.write_bytes(pcm.tobytes())
        write_wav48(out / 'audio' / f'SND{n + 1}.wav', pcm)
        extra = f' ({"; ".join(notes)})' if notes else ''
        print(f'{pcm_path}: {pcm_path.stat().st_size} bytes, {len(pcm) / SAMPLE_HZ:.2f} s{extra}')
