# I/O timing verification

Budget, sources, results and limitations: [IO_TIMING.md](../../docs/timing_closure/IO_TIMING.md).

- `run_sim.ps1`: low/high speed and early/late data, two expected-failure controls, delayed real SD protocol integration. ModelSim logs are checked, including fatal messages.
- `build.ps1 -Name <fresh-name> -Seed 3`: isolated snapshot/build/audit; keeps normal TD user output untouched. Produces routed summary, exceptions, I/O check, physical netlist, per-pin disposition and HDMI dual-edge measurements. Fails on negative timing or unexplained nodes.
- `audit_nodes.py`: classify each reported dummy pin using actual physical netlist connectivity, register input selection and unused outputs.
- `check_reports.py`: require SPI setup/hold paths, input-envelope fit, and all four HDMI lanes on both edges in both corners. Diagnostic HDMI limits never enter production builds.
- `probe.tcl`, `inspect.tcl`, `measure.sdc`: baseline investigation only, not synthesis constraints. Run from this directory; evidence from this session is archived with the candidate.

No board programming is performed by these scripts. Default SPI high-speed divider must stay at least 1 with the current 100 MHz clock and SDC. Use a new output name for each build; no cleanup/deletion is performed.
