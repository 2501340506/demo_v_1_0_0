# Build and reconstruction

Baseline: `v0.5.4-s2-board.2`. Copy `changes/` over that repository checkout; no full source backup is included here.
The TD project is byte-identical to the S2 local.2 sources/TD_project/demo.al at the baseline tag. Constraints and unchanged code come from the baseline.
Build: `diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s3_final`.
TD 6.2.168116; HighFanoutOptimization; TimingOptimization ultra; PostPlaceOptimization high; default seed.
ModelSim D:/modelsim/win64. Reproduction requires the baseline repository's unchanged dependencies and runners.
75 build source/constraint files checked byte-for-byte against workspace. Only changed/new code is copied into changes/ and compared byte-for-byte.
Bit is byte-identical to diagnostics/output/v054_s3_final/TD_project/demo_Runs/phy_1/demo.bit; 629624 bytes.
Old warning IDs: PHY-5079, PHY-7002, SYN-5011, SYN-5013, SYN-5025, SYN-6562, SYN-6577.
Current warning IDs: PHY-5079, PHY-7002, SYN-5011, SYN-5013, SYN-5025, SYN-6562, SYN-6577.
Added warning IDs: none.
Full warnings, resource usage, clock and I/O reports are retained in timing/. Existing warnings are not claimed resolved.
