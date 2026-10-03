# Current verification status

Board acceptance passed for stages 1-3. Focused simulations and TD builds passed. Full integration regression is NOT complete: tb_picture_requests.sv still uses removed ports, parameters and hierarchy. The asynchronous buffer regression was not rerun in this cycle. Mode change coincident with AUTO expiry also needs a dedicated check.

run_mode_tests.ps1 covers the switch/panel. tb_mode_key_control and tb_media_player_control have focused passing results. run_control_tests.ps1 is not currently a full passing suite because its picture test is outdated.

This documentation pass did not run simulations or TD. See [handoff](../HANDOFF.md) for next steps and [archive](../docs/history/2026-10-04/MODE_ARCHIVE.md) for original stage records.
