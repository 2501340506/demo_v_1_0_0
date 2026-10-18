"""Exhaust the arbitration implication used by the preview target mux retiming."""
from itertools import product


def check():
    checked = 0
    for publicity, pending, raw, controls, transition, preview_owner, scene, load, owns, intent, selecting, auto in product((False, True), repeat=12):
        rescan_wait = pending or raw or controls
        blocked = transition or ((pending or raw) if publicity else rescan_wait)
        preview_valid = preview_owner and not rescan_wait
        player_valid = load and not controls and not owns and not blocked and not intent and not selecting
        auto_valid = publicity and auto and not (controls or blocked)
        valid = player_valid or preview_valid or (scene and not blocked) or auto_valid
        old = 'scene' if scene else 'preview' if preview_valid else 'player'
        new = 'scene' if scene else 'preview' if preview_owner else 'player'
        assert not valid or old == new
        checked += 1
    print(f'PASS preview target mux: {checked} arbitration combinations; every valid offer retains its target')


if __name__ == '__main__':
    check()
