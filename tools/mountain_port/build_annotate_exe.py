#!/usr/bin/env python3
"""Build tools/mountain_port/annotate_scene.exe (one file, no console) with PyInstaller.

Usage: py -I tools/mountain_port/build_annotate_exe.py
Needs: py -m pip install pyinstaller (plus pillow numpy pyyaml). The exe is a
build product, not tracked (.gitignore); rebuild it after changing
annotate_scene.py, make_scene_pack.py, make_card_narration.py, scene_audio.py,
scene_text.py, hazard_v3.py or the font source it bundles. Build files go to a
temporary directory, so only the exe is left in tools/mountain_port/.
The exe runs make_scene_pack itself (annotate_scene.exe --make-scene-pack ...).
It bundles osd_font_cn_16x16.v, which scene_text reads for the 13 original
glyphs of FONT.BIN. Drawn glyphs need SimSun (simsun.ttc), which Windows has;
recorded narration needs 48 kHz mono 16-bit WAV files, or ffmpeg on PATH.
"""
from pathlib import Path
import os, sys, tempfile
import PyInstaller.__main__

here = Path(__file__).resolve().parent
root = here.parents[1]
font_source = root / 'user_source/hdl_source/osd/osd_font_cn_16x16.v'
with tempfile.TemporaryDirectory() as tmp:
    PyInstaller.__main__.run([
        str(here / 'annotate_scene.py'),
        '--name', 'annotate_scene', '--onefile', '--windowed', '--noconfirm', '--clean',
        '--paths', str(here), '--paths', str(here.parent),   # hazard_v3, make_scene_pack ...; scene_text, make_menu_thumbnails ...
        '--hidden-import', 'make_card_narration', '--hidden-import', 'scene_audio',   # imported only when --text/--audio run
        '--add-data', f'{font_source}{os.pathsep}user_source/hdl_source/osd',
        '--distpath', str(here), '--workpath', tmp, '--specpath', tmp,
        *[a for m in ('matplotlib', 'scipy', 'pandas', 'IPython', 'pytest') for a in ('--exclude-module', m)],
    ])
print(f'{here / "annotate_scene.exe"}', file=sys.stderr)
