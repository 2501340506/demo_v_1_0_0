"""Replay existing real-FAT32 handoff scenarios through the split endpoints.

Only integration wiring changes; original stimuli and assertions are preserved.
Generated files are disposable evidence, never production source.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
for relative in ['diagnostics/stability/tb_pixel_handoff.sv',
                 'diagnostics/sd_recovery/tb_rescan_handoff.sv']:
    source = (root / relative).read_text(encoding='utf-8')
    assert source.count('frame_read_write #(') == 1
    source = source.replace('frame_read_write #(', 'frame_split_test_adapter #(')
    source = source.replace('sd_card_bmp #(', 'sd_card_bmp #(.USE_FRAME_RESULT(1),')
    source = source.replace('wire valid, req, we, ack, wr_finish;',
        'wire valid, req, we, ack, wr_finish;\n'
        'wire frame_error_toggle, frame_underflow;\n'
        'wire [2:0] frame_memory_error, frame_reader_error;')
    # Both current benches declare the shared signals with the same text.
    assert 'wire frame_error_toggle' in source
    source = source.replace(".frame_error_toggle(1'b0),\n        .frame_memory_error(3'd0),.reader_error(3'd0),.reader_underflow(1'b0),\n        ", '')
    source = source.replace('.write_finish_toggle(finish_toggle)',
        '.frame_error_toggle(frame_error_toggle),.frame_memory_error(frame_memory_error),'
        '.reader_error(frame_reader_error),.reader_underflow(frame_underflow),'
        '.write_finish_toggle(finish_toggle)')
    source = source.replace(') frame (', ') frame (\n'
        '.source_done(dut.source_frame_done),.source_error(dut.source_frame_error),.display_valid(valid),'
        '.error_toggle(frame_error_toggle),.memory_error(frame_memory_error),'
        '.reader_error(frame_reader_error),.underflow(frame_underflow),')
    (out / Path(relative).name).write_text(source, encoding='utf-8')
