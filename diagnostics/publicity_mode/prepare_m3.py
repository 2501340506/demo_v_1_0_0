"""Generate explicit legacy-port adapters and a production-top M3 harness.

Only generated test copies are adapted; production and historical benches remain
the inputs. Run with py -I -X utf8. Never overwrite an existing output directory.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=False)


def complete_pins(text, module, source):
    head = source[:source.index(");")]
    start = re.search(r"\)\s*\(", head)
    if start is None:
        start = re.search(r"module\s+\w+\s*\(", head)
    ports = re.sub(r"//[^\n]*", "", head[start.end():])
    names = [re.sub(r"\[[^]]*\]", "", c).split()[-1] for c in ports.split(",")]
    values = {"map_start": "1'b0", "resource_publicity": "1'b0", "ui_play": "1'b1"}
    if module == "mode_key_control":
        values.update(scene_active="1'b0", application_busy="1'b0", scene_allowed="1'b0")
    def fill(match):
        inst = match.group()
        # Preserve existing implicit connections. Explicit empty ports override
        # .* and would disconnect the original clock, reset and key signals.
        implicit = ".*" in inst
        scope = text[:match.start()]
        missing = [n for n in names if not re.search(rf"\.{n}\s*\(", inst)
                   and not (implicit and re.search(rf"\b{n}\b", scope))]
        extra = ",".join(f".{n}({values.get(n, '')})" for n in missing)
        return inst[:-2] + (",\n" + extra if extra else "") + ");"
    return re.sub(rf"(?s)\b{module}\s*(?:#\(.*?\)\s*)?\w+\s*\(.*?\);", fill, text)


benches = [
    "mountain_scene/tb_scenario.sv", "mountain_scene/tb_scenario_cdc.sv",
    "mountain_scene/tb_scene_fade.sv", "mountain_scene/tb_scene_keys.sv",
    "mountain_scene/tb_m5_scan.sv", "mountain_scene/tb_m5_loader.sv",
    "mountain_scene/tb_m5_text.sv", "mountain_scene/tb_m6_text.sv",
    "mountain_scene/tb_scenario_top.sv", "mountain_scene/tb_scenario_pcm.sv",
    "four_bank/tb_frame_cache_control.sv", "transitions/tb_transition_s1.sv",
    "transitions/tb_transition_wipe.sv", "transitions/tb_transition_player.sv",
    "image_scaling/tb_preview_control.sv", "image_scaling/tb_preview_keys.sv",
    "image_scaling/tb_preview_player.sv", "media_adjust/tb_adjust.sv",
    "history/v0.3.0/tb_media_commit_cdc.sv", "history/v0.3.0/tb_media_player_control.sv",
    "pcm_audio/tb_pcm_production.sv", "pcm_audio/tb_pcm_preview_rescan.sv",
    "mountain_scene/tb_rgba_sdram.sv", "image_scaling/tb_preview_system.sv",
    "four_bank/tb_cache_system.sv", "mountain_scene/tb_m6_top.sv",
]
sources = {n: (ROOT / f"user_source/hdl_source/{p}").read_text(encoding="utf-8")
           for n, p in [("sd_card_bmp", "SD/sd_card_bmp.v"),
                        ("mode_key_control", "SD/mode_key_control.v"),
                        ("scenario_fsm", "scene/scenario_fsm.v"),
                        ("fat32_volume_scanner", "SD/fat32_volume_scanner.v"),
                        ("fat32_bmp_reader", "SD/fat32_bmp_reader.v"),
                        ("bmp24_decoder", "SD/bmp24_decoder.v")]}
for name in benches:
    tb = (ROOT / "diagnostics" / name).read_text(encoding="utf-8")
    if name.endswith("tb_m5_loader.sv"):
        tb = tb.replace("bin_to_bram_loader dut(", "bin_to_bram_loader #(.PIPELINED_METADATA(1)) dut(")
    if name.endswith(("tb_m6_top.sv", "tb_scenario_top.sv")):
        tb = tb.replace("top dut(", "top #(.PUBLICITY_ENABLE(0)) dut(")
    for module, source in sources.items():
        tb = complete_pins(tb, module, source)
    (out / Path(name).name).write_text(tb, encoding="utf-8")

# Use the scanner/card/write ownership model from the M3 controller test. Top
# controls, application FSMs, scaler, pixel pipeline and volume stay real.
tb = (ROOT / "diagnostics/publicity_mode/tb_m3_reload.sv").read_text(encoding="utf-8")
tb = tb.replace("module tb_m3_reload #(parameter CARD_CASE=0, SCALE=0, AUDIO=0);",
                "module tb_m3_top; localparam CARD_CASE=0,SCALE=1,AUDIO=1;")
start = tb.index(" sd_card_bmp #(")
end = tb.index(" initial begin", start)
tb = tb[:start] + '''
 reg hs=1,vs=1,de=0;reg [9:0] vx=0;
 top top_dut(.clk(clk),.rst_n(!rst),.key1(k1),.key2(k2),.key4(k4),
 .sw1(mode[0]),.sw2(mode[1]),.sd_miso(1'b1),.uart_rx(1'b1));
 defparam top_dut.sd_card_bmp_m0.CLK_FREQ_HZ=1000;
 defparam top_dut.sd_card_bmp_m0.LOAD_TIMEOUT_MS=10000;
 defparam top_dut.u_switch_mode_control.CLK_FREQ_HZ=1000;
 assign app=top_dut.application_mode;assign busy=top_dut.application_busy;
 assign error=top_dut.application_error;assign identity=top_dut.display_identity;
 assign level=top_dut.transition_level;assign wr=top_dut.sd_card_write_req;
 assign we=top_dut.sd_card_write_en;assign wb=top_dut.write_buf_idx;
 assign db=top_dut.disp_buf_idx;assign data=top_dut.sd_card_write_data;
 assign source_done=top_dut.source_frame_done;assign cancel=top_dut.write_cancel_req;
 assign display_req=top_dut.display_commit_request;assign preview_req=top_dut.preview_request;
 initial begin
 force top_dut.video_clk=pix;force top_dut.sd_card_clk=clk;
 force top_dut.rst_video=rst;force top_dut.rst_sd=rst;force top_dut.rst_panel=rst;
 force top_dut.rst_mem=1;force top_dut.Sdr_init_done=1;
 force top_dut.sd_card_write_req_ack=ack;force top_dut.frame_write_toggle_mem=finish;
 force top_dut.frame_write_ready=1;force top_dut.write_cancel_ack=cancel_ack;
 force top_dut.display_commit_ack=display_ack;force top_dut.preview_ack=preview_ack;
 force top_dut.frame_error_toggle=0;force top_dut.frame_memory_error=0;
 force top_dut.frame_reader_error=0;force top_dut.frame_underflow=0;
 force top_dut.hs=hs;force top_dut.vs=vs;force top_dut.de=de;force top_dut.video_x=vx;
 force top_dut.vout_rgba_raw=32'h12345680;force top_dut.pixel_descriptor=0;
 end
''' + tb[end:]
tb = tb.replace("dut.", "top_dut.sd_card_bmp_m0.")
# Above replacement also touches the deliberate top_dut references.
tb = tb.replace("top_top_dut.sd_card_bmp_m0.", "top_dut.")
tb = tb.replace("if(frame_div==100)begin", "if(frame_div==8000)begin")
tb = tb.replace("frame_div++;", '''frame_div++;
 vx=frame_div%800;vs=frame_div>=800;de=frame_div>=800 && frame_div<7200 && vx<640;
 hs=!(vx>=656 && vx<752);''')
# Tests use real video frames and scan, not forced application/commit states.
start = tb.index(" integer b0,d0,c0,i;")
tb = tb[:start] + '''
 reg [12:0] timing_pipe[0:2];integer timing_checks=0,muted_samples=0,plain_pixels=0,scene_pixels=0;
 reg [23:0] hazard_pipe[0:9];
 always @(posedge pix)if(!rst)begin
  timing_pipe[2]=timing_pipe[1];timing_pipe[1]=timing_pipe[0];
  timing_pipe[0]={top_dut.ring_hs,top_dut.ring_vs,top_dut.ring_de,top_dut.ring_x};
  for(integer h=9;h>0;h--)hazard_pipe[h]=hazard_pipe[h-1];hazard_pipe[0]=top_dut.vout_data;
  #1;
  if(timing_checks>3 && {top_dut.final_hs,top_dut.final_vs,top_dut.final_de,top_dut.final_x}!==timing_pipe[2])$fatal(1,"top final timing bundle");
  timing_checks++;
  if(!busy && app==1 && de)begin
   if(top_dut.pixel_identity!==identity || top_dut.scene_text_active)$fatal(1,"top publicity identity/layers");
   if(top_dut.hazard_rgb!==hazard_pipe[9])$fatal(1,"publicity hazard bypass");
   plain_pixels++;
   if(!top_dut.scenario_muted)$fatal(1,"publicity not muted");
   if(top_dut.volume_valid && top_dut.volume_ready)begin
    if(top_dut.volume_left!==0 || top_dut.volume_right!==0)$fatal(1,"publicity tone leaked");
    muted_samples++;
   end
  end
  if(!busy && app==2 && de)begin
   if(top_dut.pixel_identity!==identity || !top_dut.scene_enable)$fatal(1,"top scene identity");
   scene_pixels++;
  end
 end
 integer b0,d0,i;reg [7:0] saved_b,saved_c;reg [3:0] saved_v;
 initial begin
  for(i=0;i<4;i++)begin bank_good[i]=0;bank_count[i]=0;bank_id[i]=0;end
  setup();cycles(10);rst=0;settled(1);wait(top_dut.sd_card_bmp_m0.cache_valid==15);
  b0=boots;d0=dirs;next_page();page(1);prev_page();page(0);
  // Parameter events through actual keys and debounced switch routing.
  mode=1;cycles(100);k2=0;cycles(70);k2=1;cycles(100);
  short4();k1=0;cycles(70);k1=1;cycles(100);
  mode=2;cycles(100);k1=0;cycles(70);k1=1;cycles(100);
  saved_b=top_dut.brightness_src;saved_c=top_dut.contrast_src;saved_v=top_dut.volume_src;
  if(saved_b==128 || saved_c==128 || saved_v==10)$fatal(1,"top parameter gestures");
  mode=0;cycles(100);toggle_app();settled(2);
  k1=0;cycles(1100);k1=1;cycles(100);
  if(top_dut.sd_card_bmp_m0.g_scenario.speed!=1)$fatal(1,"speed gesture");
  prev_page();wait(top_dut.sd_card_bmp_m0.g_scenario.warn_mode);wait(!top_dut.sd_card_bmp_m0.scene_fade);
  toggle_app();settled(1);
  if(top_dut.brightness_src!=saved_b || top_dut.contrast_src!=saved_c || top_dut.volume_src!=saved_v)$fatal(1,"parameters lost across apps");
  toggle_app();settled(2);
  if(top_dut.sd_card_bmp_m0.g_scenario.speed!=1 || top_dut.sd_card_bmp_m0.g_scenario.warn_mode)$fatal(1,"scene speed/warning reentry");
  toggle_app();settled(1);
  if(boots!=b0 || dirs!=d0 || muted_samples<4 || plain_pixels==0 || scene_pixels==0)$fatal(1,"top coverage");
  $display("PASS M3 production top: %0d HDMI timing checks %0d publicity pixels %0d scene pixels %0d silent PCM samples, actual scaler/identity CDC/keys/parameters",timing_checks,plain_pixels,scene_pixels,muted_samples);$finish;
 end
 reg [3:0] last_app_state=15;
 always @(negedge clk)if(!rst && top_dut.sd_card_bmp_m0.g_application.application.state!=last_app_state)begin
  last_app_state=top_dut.sd_card_bmp_m0.g_application.application.state;
  $display("M3 top progress t=%0t state=%0d app=%0d reads=%0d commits=%0d",$time,last_app_state,app,reads,commits);
 end
 always @(negedge clk)if(source_done)$display("M3 top full source t=%0t pixels=%0d",$time,pixels);
 initial begin #3000000000;$fatal(1,"M3 top watchdog state=%d app=%d busy=%b",top_dut.sd_card_bmp_m0.g_application.application.state,app,busy);end
endmodule
'''
(out / "tb_m3_top.sv").write_text(tb, encoding="utf-8")
print(f"Prepared {len(benches)} regression benches and production top in {out}")
