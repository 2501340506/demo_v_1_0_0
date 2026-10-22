"""v0.25 S4: the scene annotation tool's card text check, card install and dialogs.

py -I -X utf8 diagnostics/annotate_tool/test_annotate_tool.py [-v]
The window tests need a desktop (Tk); without one they are skipped. The full
generate-from-the-window run takes about two minutes: set ANNOTATE_SLOW=1.
"""
import copy
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
PORT = ROOT / 'tools/mountain_port'
sys.path.insert(0, str(PORT))
import annotate_scene as tool  # noqa: E402

SCENE = PORT / 'scenes/landslide_village'
GENERATED = ROOT / 'releases/v0.25.0/s2-card.1/card/landslide_village'


def load_cfg():
    return yaml.safe_load((SCENE / 'scene.yaml').read_text(encoding='utf-8'))


def widgets(w):
    for c in w.winfo_children():
        yield c
        yield from widgets(c)


class CardTextStatus(unittest.TestCase):
    def test_complete_text_is_ok(self):
        state, why = tool.card_text_status(load_cfg())
        self.assertEqual(state, 'ok', why)
        self.assertRegex(why, r'字形 \d+/128')      # the legends are part of the check

    def test_no_text_is_none(self):
        cfg = load_cfg()
        for k in ('village', 'warning'):
            cfg.pop(k)
        for st in cfg['stages']:
            st.pop('title'), st.pop('subtitle'), st.pop('legend', None)
        self.assertEqual(tool.card_text_status(cfg)[0], 'none')

    def test_partial_and_bad_text(self):
        cfg = load_cfg()
        del cfg['stages'][2]['subtitle']
        state, why = tool.card_text_status(cfg)
        self.assertEqual(state, 'bad')
        self.assertIn('subtitle', why)
        cfg = load_cfg()
        cfg['stages'][0]['subtitle'] = '字' * 16
        self.assertEqual(tool.card_text_status(cfg)[0], 'bad')            # 15 characters at most
        cfg = load_cfg()
        cfg['warning'] = '红' * 20
        self.assertEqual(tool.card_text_status(cfg)[0], 'bad')            # 19 at most
        cfg = load_cfg()
        cfg['village'] = 'ABC村'
        state, why = tool.card_text_status(cfg)
        self.assertEqual(state, 'bad')
        self.assertIn('CJK', why)                                         # no Latin letters in TEXT.BIN
        cfg = load_cfg()
        for n, st in enumerate(cfg['stages']):                            # more than 128 distinct glyphs
            st['title'] = ''.join(chr(0x4e00 + n * 40 + i) for i in range(19))
            st['subtitle'] = ''.join(chr(0x5000 + n * 40 + i) for i in range(15))
        cfg['village'] = ''.join(chr(0x6000 + i) for i in range(19))
        cfg['warning'] = ''.join(chr(0x6100 + i) for i in range(19))
        state, why = tool.card_text_status(cfg)
        self.assertEqual((state, 'FONT' in why), ('bad', True), why)


class Legends(unittest.TestCase):
    def test_parse_and_format_round_trip(self):
        items = tool.parse_legend('danger 危险区; route 撤离路线；Refuge 避险点 ')
        self.assertEqual(items, [['danger', '危险区'], ['route', '撤离路线'], ['refuge', '避险点']])
        self.assertEqual(tool.parse_legend(tool.format_legend(items)), items)
        self.assertEqual(tool.parse_legend(''), [])
        with self.assertRaises(ValueError):
            tool.parse_legend('危险区')                                    # no swatch name

    def test_unknown_swatch_and_long_legend_are_bad(self):
        cfg = load_cfg()
        cfg['stages'][0]['legend'] = [['purple', '紫色']]
        state, why = tool.card_text_status(cfg)
        self.assertEqual(state, 'bad')
        self.assertIn('purple', why)
        cfg = load_cfg()
        cfg['stages'][3]['legend'] = [['danger', '危' * 16], ['route', '路' * 12]]       # 18 + 14 + 2 cells
        state, why = tool.card_text_status(cfg)
        self.assertEqual(state, 'bad')
        self.assertIn('31', why)

    def test_legends_make_a_fourteen_segment_text(self):
        cfg = load_cfg()
        spec = tool.mcn.text_spec(cfg, 'scene.yaml', legends=True)
        font, text, meta = tool.scene_text.encode_text(spec, cfg['stages'])
        self.assertEqual((text[3], len(meta['segments'])), (14, 14))
        self.assertTrue(all(0xe0 <= c < 0xe8 for c in text[text[4 + 4 * 10]:text[4 + 4 * 10] + 1]))   # a swatch leads
        tool.mcn.validate_text(font, text, meta, spec)
        plain = tool.mcn.text_spec(cfg, 'scene.yaml')                      # without --legends: 10 segments as in S2
        self.assertEqual(tool.scene_text.encode_text(plain, cfg['stages'])[1][3], 10)
        cfg2 = load_cfg()
        for st in cfg2['stages']:
            st.pop('legend', None)
        spec2 = tool.mcn.text_spec(cfg2, 'scene.yaml', legends=True)       # no legend anywhere: still 10 segments
        self.assertNotIn('legends', spec2)


class CardInstall(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='annotate_test_'))
        self.sd = self.tmp / 'out/sd'
        self.sd.mkdir(parents=True)
        self.card = self.tmp / 'card/情景模式'
        self.dest = self.card / 'landslide_village'
        self.dest.mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def header(self, hazard, stage):
        return b'BM' + bytes(4) + bytes([hazard, stage]) + bytes(20)

    def make_sd(self, hazard=1, names=None):
        for f in names or ['PIC1.BMP', 'PIC2.BMP', 'PIC3.BMP', 'PIC4.BMP', 'THUMB.BMP']:
            data = self.header(hazard, int(f[3])) + f.encode() if f.startswith('PIC') else f.encode() * 3
            (self.sd / f).write_bytes(data)

    def test_replace_backup_and_leave_others(self):
        self.make_sd(names=['PIC1.BMP', 'PIC2.BMP', 'PIC3.BMP', 'PIC4.BMP', 'THUMB.BMP', 'FONT.BIN', 'TEXT.BIN', 'SND1.PCM'])
        (self.dest / 'PIC1.BMP').write_bytes(b'old pic')
        (self.dest / 'SND2.PCM').write_bytes(b'old sound 2')          # not in the new card: stale
        other = self.card / 'flood_village'
        other.mkdir()
        (other / 'PIC1.BMP').write_bytes(b'flood')
        res = tool.install_card(self.sd, self.tmp / 'card', 'landslide')     # card root accepted
        self.assertEqual(sorted(res['new']), sorted(p.name for p in self.sd.iterdir()))
        for f in res['new']:
            self.assertEqual((self.dest / f).read_bytes(), (self.sd / f).read_bytes())
        self.assertEqual(res['replaced'], ['PIC1.BMP'])
        self.assertEqual(res['moved'], ['SND2.PCM'])
        self.assertFalse((self.dest / 'SND2.PCM').exists())
        self.assertEqual((res['backup'] / 'PIC1.BMP').read_bytes(), b'old pic')
        self.assertEqual((res['backup'] / 'SND2.PCM').read_bytes(), b'old sound 2')
        self.assertEqual((other / 'PIC1.BMP').read_bytes(), b'flood')

    def test_keep_stale(self):
        self.make_sd()
        (self.dest / 'TEXT.BIN').write_bytes(b'old text')
        res = tool.install_card(self.sd, self.card, 'landslide', keep_stale=True)
        self.assertEqual((res['moved'], (self.dest / 'TEXT.BIN').read_bytes()), ([], b'old text'))
        self.assertEqual(tool.card_install_plan(self.sd, self.card, 'landslide')['stale'], ['TEXT.BIN'])

    def test_refusals_leave_the_card_untouched(self):
        (self.dest / 'PIC1.BMP').write_bytes(b'old pic')
        self.make_sd(hazard=3)                                     # flood pictures into the landslide folder
        with self.assertRaises(ValueError):
            tool.install_card(self.sd, self.card, 'landslide')
        self.make_sd(hazard=1)
        (self.sd / 'PIC3.BMP').unlink()
        with self.assertRaises(ValueError):
            tool.install_card(self.sd, self.card, 'landslide')
        self.make_sd(hazard=1)
        with self.assertRaises(ValueError):
            tool.install_card(self.sd, self.tmp / 'nowhere', 'landslide')
        with self.assertRaises(ValueError):
            tool.install_card(self.sd, self.card, 'volcano')
        self.assertEqual({p.name for p in self.dest.iterdir()}, {'PIC1.BMP'})
        self.assertEqual((self.dest / 'PIC1.BMP').read_bytes(), b'old pic')
        self.assertFalse((self.tmp / 'out/card_backup').exists())

    def test_every_hazard_has_its_folder(self):
        names = {'landslide': 'landslide_village', 'debris_flow': 'debris_village', 'flood': 'flood_village', 'earthquake': 'quake_village'}
        self.assertEqual(tool.CARD_FOLDERS, names)
        for hazard, folder in names.items():
            self.make_sd(hazard=tool.v3.HAZARDS[hazard])
            self.assertEqual(tool.card_install_plan(self.sd, self.card, hazard)['dest'].name, folder)


class Windows(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import tkinter as tk
        try:
            cls.root = tk.Tk()
        except tk.TclError as e:
            raise unittest.SkipTest(f'no display: {e}')
        cls.root.withdraw()

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, 'root'):
            cls.root.destroy()

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='annotate_win_'))
        self.scene = self.tmp / 'landslide_village'
        shutil.copytree(SCENE, self.scene, ignore=shutil.ignore_patterns('voice', 'out', '__pycache__'))
        self.app = tool.App(self.root, str(self.scene / 'scene.yaml'))

    def tearDown(self):
        for w in self.root.winfo_children():
            if w.winfo_class() == 'Toplevel':
                w.destroy()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def dialog(self):
        before = set(self.root.winfo_children())
        self.app.card_text_dialog()
        self.root.update()
        top = next(w for w in self.root.winfo_children() if w not in before)
        entries = [w for w in widgets(top) if w.winfo_class() == 'TEntry']
        button = lambda text: next(w for w in widgets(top) if w.winfo_class() == 'TButton' and w.cget('text') == text)
        label = [w for w in widgets(top) if w.winfo_class() == 'TLabel' and w.cget('text').startswith(('可以生成', '没有填', '还没', '字', '每'))]
        return top, entries, button, label

    def test_dialog_shows_and_applies_the_text(self):
        top, entries, button, label = self.dialog()
        self.assertEqual(len(entries), 14)
        self.assertEqual(entries[0].get(), '青石坡村')
        self.assertEqual(entries[2].get(), '阶段1 致因：强降雨')
        self.assertEqual(entries[4].get(), 'zone 滑坡隐患区; rain 强降雨')
        self.assertTrue(any(l.cget('text').startswith('可以生成') for l in label))
        entries[1].delete(0, 'end')
        entries[1].insert(0, '红色预警！立即撤离滑坡区！')
        entries[5].delete(0, 'end')                                  # PIC2 标题 cleared: incomplete
        self.root.update()
        self.assertTrue(any(l.cget('foreground') in ('#b00', '#b00000') or str(l.cget('foreground')) == '#b00' for l in widgets(top)
                            if l.winfo_class() == 'TLabel'))
        entries[5].insert(0, '阶段2 发生：坡体下滑')
        entries[4].delete(0, 'end')
        entries[4].insert(0, 'mud 滑坡体; rock 落石')
        self.root.update()
        button('确定').invoke()
        self.assertEqual(self.app.cfg['warning'], '红色预警！立即撤离滑坡区！')
        self.assertEqual(self.app.cfg['stages'][0]['legend'], [['mud', '滑坡体'], ['rock', '落石']])
        self.assertTrue(self.app.dirty)
        self.assertEqual(tool.card_text_status(self.app.cfg)[0], 'ok')

    def test_clearing_everything_removes_the_keys(self):
        top, entries, button, _ = self.dialog()
        for e in entries:
            e.delete(0, 'end')
        self.root.update()
        button('确定').invoke()
        cfg = self.app.cfg
        self.assertNotIn('village', cfg)
        self.assertTrue(all('title' not in s and 'subtitle' not in s and 'legend' not in s for s in cfg['stages']))
        self.assertTrue(all(s.get('narration') for s in cfg['stages']))      # narration is untouched

    def test_save_keeps_narration_and_text(self):
        self.app.save_as = None
        self.app.had_comments = False
        self.app.save()
        saved = yaml.safe_load((self.scene / 'scene.yaml').read_text(encoding='utf-8'))
        self.assertEqual(saved['village'], '青石坡村')
        self.assertEqual(saved['stages'][1]['narration'][1]['file'], 'voice/landslide_s2_t065.wav')
        self.assertEqual(saved['stages'][3]['sound_loop'], True)
        self.assertEqual(saved['stages'][3]['sound'], load_cfg()['stages'][3]['sound'])

    @unittest.skipUnless(os.environ.get('ANNOTATE_SLOW'), 'set ANNOTATE_SLOW=1 (about two minutes)')
    def test_generate_writes_the_whole_card(self):
        # The scene references ../../../publicity/... for the siren; keep the copy beside the original.
        shutil.rmtree(self.scene)
        self.scene = SCENE.parent / '_annotate_test_copy'
        shutil.copytree(SCENE, self.scene, ignore=shutil.ignore_patterns('out', '__pycache__'))
        try:
            self.app = tool.App(self.root, str(self.scene / 'scene.yaml'))
            tool.messagebox.askokcancel = lambda *a, **k: True        # "saving drops the # comments" prompt
            self.app.generate()
            import time
            for _ in range(2400):
                self.root.update()
                if str(self.app.gen_btn.cget('state')) == 'normal':
                    break
                time.sleep(0.1)
            log = self.app.logbox.get('1.0', 'end')
            sd = self.scene / 'out/sd'
            self.assertTrue(sd.is_dir(), log)
            self.assertEqual(sorted(p.name for p in sd.iterdir()), sorted(tool.CARD_FILES))
            self.assertEqual(sd.joinpath('TEXT.BIN').read_bytes()[3], 14)                        # legends are on
            for f in ('SND1.PCM', 'SND4.PCM'):
                self.assertEqual((sd / f).read_bytes(), (GENERATED / f).read_bytes(), f)
        finally:
            shutil.rmtree(self.scene, ignore_errors=True)


if __name__ == '__main__':
    unittest.main()
