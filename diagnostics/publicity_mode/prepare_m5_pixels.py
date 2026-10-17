"""Production top: actual decoded/scaled writes feed the external frame model.

Only SD wire transport and external SDRAM handshakes/readout are modeled.
The other SDRAM/preview regressions exercise the actual SDRAM read path.
"""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1])
s=(out/'tb_m3_top.sv').read_text(encoding='utf-8')
s=s[:s.index(' reg [12:0] timing_pipe')]
s=s.replace('module tb_m3_top;', 'module tb_m5_pixels;')
s=s.replace(' reg clk=0;', " reg [31:0] frame_memory[0:1228799];reg [31:0] memory_pixel=0;\n reg [17:0] memory_descriptor=0;\n reg clk=0;")
s=s.replace(' force top_dut.vout_rgba_raw=32\'h12345680;force top_dut.pixel_descriptor=0;',
            ' force top_dut.vout_rgba_raw=memory_pixel;force top_dut.pixel_descriptor=memory_descriptor;')
s=s.replace(' pixels++;', ' frame_memory[writing_bank*307200+pixels]=data;\n pixels++;')
s=s.replace('frame_div<7200','frame_div<52000').replace('frame_div==8000','frame_div==52800')
s=s.replace('preview_ack=preview_req;', 'preview_ack=preview_req;memory_descriptor=top_dut.preview_descriptor;')
# Nontrivial arrival-time RGBA on scene pictures, preserving 2x2/70-byte BMPs.
s=s.replace("8'(expected_cluster),8'hff}", "8'(expected_cluster),(expected_cluster<16?8'h00:8'hff)}")
s+=(ROOT/'diagnostics/publicity_mode/tb_m5_pixels_body.svh').read_text(encoding='utf-8')
(out/'tb_m5_pixels.sv').write_text(s,encoding='utf-8')
