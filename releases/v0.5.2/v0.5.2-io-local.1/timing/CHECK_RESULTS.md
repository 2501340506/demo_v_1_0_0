# Candidate timing checks

- Setup +0.148 ns; Hold +0.011 ns.
- MISO internal path + setup + 0.100 ns uncertainty: 3.633 ns <= 4.200 ns.
- HDMI full corner/edge arrival spread: 1.189 ns; +0.250 ns board mismatch +0.500 ns reserve <= 2 ns engineering aperture.
- HDMI measurement limits are diagnostic only; production path limit is 3.500 ns.

|Port|Check/corner|Launch edge|Clock-to-pad ns|Arrival from reference ns|
|---|---|---|---:|---:|
|HDMI_CLK_P|setup|rising|2.573|4.233|
|HDMI_CLK_P|setup|falling|2.573|4.404|
|HDMI_CLK_P|hold|rising|2.031|3.215|
|HDMI_CLK_P|hold|falling|2.031|3.342|
|HDMI_D0_P|setup|rising|2.573|4.233|
|HDMI_D0_P|setup|falling|2.573|4.404|
|HDMI_D0_P|hold|rising|2.031|3.215|
|HDMI_D0_P|hold|falling|2.031|3.342|
|HDMI_D1_P|setup|rising|2.573|4.233|
|HDMI_D1_P|setup|falling|2.573|4.404|
|HDMI_D1_P|hold|rising|2.031|3.215|
|HDMI_D1_P|hold|falling|2.031|3.342|
|HDMI_D2_P|setup|rising|2.573|4.233|
|HDMI_D2_P|setup|falling|2.573|4.404|
|HDMI_D2_P|hold|rising|2.031|3.215|
|HDMI_D2_P|hold|falling|2.031|3.342|
