"""Generate a repeatable audition corpus and verify the real FFmpeg conversion."""
import math
from pathlib import Path
import struct
import subprocess
import sys
import wave

root=Path(__file__).resolve().parents[2]
out=root/'diagnostics/output'/sys.argv[1]
out.mkdir(parents=True,exist_ok=False)
def wav(path,channels,rate,samples):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate);w.writeframes(samples)
# A three-second periodic sine can be copied to the card for manual listening.
mono=b''.join(struct.pack('<h',round(12000*math.sin(2*math.pi*440*i/48000))) for i in range(144000))
wav(out/'audition_440Hz.wav',1,48000,mono)
subprocess.run([sys.executable,str(root/'tools/make_audio_corpus.py'),str(out/'audition_440Hz.wav'),str(out/'BGM.PCM')],check=True)
assert (out/'BGM.PCM').read_bytes()==mono, '48k mono samples changed'
stereo=b''.join(struct.pack('<hh',1000,-1000) for _ in range(44100))
wav(out/'stereo_44100.wav',2,44100,stereo)
subprocess.run([sys.executable,str(root/'tools/make_audio_corpus.py'),str(out/'stereo_44100.wav'),str(out/'stereo_converted.pcm')],check=True)
converted=(out/'stereo_converted.pcm').read_bytes()
assert len(converted)==96000, 'resampled duration differs'
assert max(abs(x[0]) for x in struct.iter_unpack('<h',converted))<=1, 'stereo mix not centered'
# Deterministic signed endpoints are useful for byte-order and gain probes.
probe=struct.pack('<hhhhhhhh',-32768,-32767,-2,-1,0,1,32766,32767)
wav(out/'signed_endpoints.wav',1,48000,probe)
subprocess.run([sys.executable,str(root/'tools/make_audio_corpus.py'),str(out/'signed_endpoints.wav'),str(out/'signed_endpoints.pcm')],check=True)
assert (out/'signed_endpoints.pcm').read_bytes()==probe
(out/'RESULT.txt').write_text('PASS conversion: exact 144000 mono samples, 44.1k stereo to 48000 mono samples, signed endpoints\n',encoding='utf-8')
print((out/'RESULT.txt').read_text())
