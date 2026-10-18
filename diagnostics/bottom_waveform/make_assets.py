"""New publicity images; preserve historical media, voices and source records."""
import argparse
import importlib.util
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def generate(output):
    assert not output.exists(), 'Use a new output directory'
    renderer = module('renderer', ROOT/'tools/publicity/geohazard_basics/make_inputs.py')
    pack = module('pack', ROOT/'tools/make_publicity_pack.py')
    old = ROOT/'tools/publicity/geohazard_release'
    report = renderer.generate(output/'inputs', Path('C:/Windows/Fonts/simhei.ttf'),
                               old/'content.yaml', test_tones=False, bottom_waveform=True)
    (output/'card').mkdir()
    (output/'preview').mkdir()
    overview = Image.new('RGB', (1280, 960))
    manifest = {'image_layout': 'full-width bottom waveform; footer removed',
                'waveform_reserved': [0, 452, 640, 480],
                'subtitle_band': [8, 420, 632, 444], 'pages': []}
    for i, page in enumerate(report['pages'], 1):
        image = Image.open(output/f'inputs/page{i}.png').convert('RGB')
        original = Image.open(old/f'inputs/page{i}.png').convert('RGB')
        assert image.crop((0, 0, 640, 210)).tobytes() == original.crop((0, 0, 640, 210)).tobytes()
        assert image.crop((0, 210, 420, 386)).tobytes() == original.crop((0, 210, 420, 386)).tobytes()
        assert all(b['box'][3] <= 420 for b in page['text_bounds'])
        assert len(page['text_bounds']) == len(json.loads((old/'inputs/generation.json').read_text(encoding='utf-8'))['pages'][i-1]['text_bounds'])-2
        assert set(image.crop((0, 420, 640, 480)).getdata()) == {(244, 246, 237)}
        bmp = pack.bmp24(image)
        target = output/f'card/EDU{i}.BMP'
        target.write_bytes(bmp)
        assert pack.read_bmp24(target.read_bytes()).tobytes() == image.tobytes()
        image.save(output/f'preview/EDU{i}.png')
        overview.paste(image, (((i-1)%2)*640, ((i-1)//2)*480))
        # Preview uses actual PCM peaks, exactly the RTL's 32-sample windows.
        import struct
        samples = struct.unpack('<'+'h'*((old/f'generated/VOI{i}.PCM').stat().st_size//2),
                                (old/f'generated/VOI{i}.PCM').read_bytes())
        frames=[]
        for frame in range(30):
            end=48000+frame*800
            result=image.copy(); draw=ImageDraw.Draw(result)
            for bar in range(80):
                start=end-(80-bar)*32
                height=min(28,max(abs(v) for v in samples[start:start+32])>>9)
                if height: draw.rectangle((bar*8+2,480-height,bar*8+4,479),fill='#b45ac8')
            frames.append(result)
        frames[0].save(output/f'preview/EDU{i}_waveform.gif', save_all=True,
                       append_images=frames[1:], duration=33, loop=0)
        manifest['pages'].append({'id':i,'file':target.name,'bytes':len(bmp),
                                  'text_bounds':page['text_bounds']})
    overview.save(output/'preview/overview.png')
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS four new BMPs: exact decode/readback, original body/title, no footer text; empty subtitle/waveform area; actual-PCM previews')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    generate(parser.parse_args().output)
