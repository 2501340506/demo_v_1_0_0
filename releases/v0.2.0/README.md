# v0.2.0 - Switch modes and independent keys

Archive date: 2026-10-04. Archive version only; no new Git tag or GitHub Release. Based on v0.1.9.

Mode 00: KEY1 previous, KEY2 next. Modes 01/10/11: no new direction requests. KEY4 toggles MAN/AUTO in all modes when scanning is complete and more than one image exists. Held keys do not repeat. Mode changes reset the AUTO timer. Pending directions retain the original coalescing and next-before-previous priority.

Board acceptance passed for stages 1-3. Focused simulations and TD builds passed. Full integration regression is NOT complete: tb_picture_requests.sv still uses removed ports, parameters and hierarchy. The asynchronous buffer regression was not rerun in this cycle. Mode change coincident with AUTO expiry also needs a dedicated check.

## Fixed artifacts

- demo.bit: copied from the board-accepted stage 3 build, 629624 bytes. No rebuild in this pass.
- demo_phy.ts, demo_phy.area, demo_pr.timing: actual stage 3 reports.
- build_mode_stage3.log: implementation log.
- synthesis_mode_stage3.log: synthesis log.

Setup WNS -6.699 ns, TNS -295.899 ns; Hold WNS +0.003 ns, TNS 0 ns. Timing is not closed.

No OSD, brightness/contrast adjustment or scaling. B: initial 0, range -128..127. C: initial 128, range 0..256, at least 9 bits. These are future requirements only.
