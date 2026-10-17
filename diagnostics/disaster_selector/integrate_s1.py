"""One-shot selective integration of typed metadata into the existing chain."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
def edit(path, changes):
    p = root / path
    s = p.read_text(encoding='utf-8')
    for old, new in changes:
        assert old in s, (path, old)
        s = s.replace(old, new)
    p.write_text(s, encoding='utf-8', newline='\n')

edit('user_source/hdl_source/SD/fat32_bmp_reader.v', [
 ('output reg load_done,load_error,', 'output reg [7:0] loaded_kind,\n output reg load_done,load_error,'),
 ('reg stream_finished,decode_finished;', '''reg stream_finished,decode_finished;
 // Read type from the actual file stream, never from a scan or preload of
 // another image. Invalid/ordinary tags pass through; zero retains v1.
 reg [7:0] kind_hazard,kind_role;
 always @(posedge clk or posedge rst)begin
  if(rst)begin kind_hazard<=0;kind_role<=0;loaded_kind<=0;end
  else begin
   if(state==START_FILE)begin kind_hazard<=0;kind_role<=0;end
   if(state==READ_FILE && stream_valid)begin
    if(stream_offset==6)kind_hazard<=stream_byte;
    if(stream_offset==7)kind_role<=stream_byte;
   end
   if(state==RESULT && bmp_error==0)
    loaded_kind<=kind_hazard==0 && kind_role==0 ? 8'd0 :
      kind_hazard>=1 && kind_hazard<=4 && kind_role>=1 && kind_role<=4 ?
      {kind_hazard[3:0],kind_role[3:0]} : 8'hff;
  end
 end''')])
edit('user_source/hdl_source/SD/sd_card_bmp.v', [
 ('output reg [5:0] display_identity,', 'output reg [5:0] display_identity,\n    output reg [7:0] display_kind,'),
 ('wire load_request,load_accept,load_result_valid,load_result_ready,load_success,load_timeout;', '''wire load_request,load_accept,load_result_valid,load_result_ready,load_success,load_timeout;
wire [7:0] loaded_kind;
reg [7:0] bank_kind[0:3];
integer kind_i;
always @(posedge clk or posedge rst)begin
 if(rst)for(kind_i=0;kind_i<4;kind_i=kind_i+1)bank_kind[kind_i]<=0;
 else if(load_result_valid && load_result_ready && load_success)
  bank_kind[write_buf_idx]<=loaded_kind;
end'''),
 ('display_identity<=0;end', 'display_identity<=0;display_kind<=0;end'),
 ('display_identity<={resource_version,scan_application};', 'display_identity<={resource_version,scan_application};\n   display_kind<=bank_kind[cache_display_bank];'),
 ('.load_done(bmp_load_done),.load_error(parser_load_error)', '.loaded_kind(loaded_kind),.load_done(bmp_load_done),.load_error(parser_load_error)')])
edit('user_source/hdl_source/top_tf_hdmi_audio.v', [
 ('wire [7:0] committed_bundle;', 'wire [15:0] committed_bundle;\nwire [7:0] display_kind;\nreg [7:0] pixel_kind,pending_kind;'),
 ('identity_pending<=0;end', 'identity_pending<=0;pixel_kind<=0;pending_kind<=0;end'),
 ('pending_identity<=committed_bundle[7:2];identity_pending<=1;', 'pending_identity<=committed_bundle[7:2];pending_kind<=committed_bundle[15:8];identity_pending<=1;'),
 ('pixel_identity<=pending_identity;identity_pending<=0;', 'pixel_identity<=pending_identity;pixel_kind<=pending_kind;identity_pending<=0;'),
 ('.display_identity(display_identity),', '.display_identity(display_identity),.display_kind(display_kind),'),
 ('hazard_layer #(.SIDE_WIDTH(48)) u_hazard(', '''reg [9:0] hazard_frame_count;
always @(posedge video_clk or posedge rst_video)begin
 if(rst_video)hazard_frame_count<=0;
 else if(sub_frame_start)hazard_frame_count<=hazard_frame_count+1'b1;
end
disaster_layer #(.SIDE_WIDTH(48)) u_hazard('''),
 ('.stage(scene_stage),.t_now(scene_time),.enable(', '.kind(pixel_kind),.de(de),.frame_start(sub_frame_start),.frame_cnt(hazard_frame_count),\n .stage(scene_stage),.t_now(scene_time),.enable('),
 ('media_commit_cdc #(.WIDTH(8))', 'media_commit_cdc #(.WIDTH(16))'),
 ('.src_image({display_identity,committed_image})', '.src_image({display_kind,display_identity,committed_image})')])
edit('TD_project/demo.al', [
 ('        </Verilog>', '''            <File Path="../user_source/hdl_source/scene/hazard_layer_v3.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="109"/>
                </FileInfo>
            </File>
            <File Path="../user_source/hdl_source/scene/disaster_layer.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="110"/>
                </FileInfo>
            </File>
        </Verilog>''')])
edit('diagnostics/disaster_selector/make_hazard_vectors3.py', [
 ("ROOT / 'tools'", "ROOT / 'tools/mountain_port'")])
