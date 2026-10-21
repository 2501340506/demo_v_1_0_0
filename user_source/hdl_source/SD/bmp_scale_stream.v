// SHARED_HEADER=1: the decoder's header parser is outside (bmp24_decoder_core
// header_feed/header_result buses); otherwise the decoder keeps its own.
module bmp_scale_stream #(parameter NATIVE_THUMB_ENABLE=0, SHARED_HEADER=0)(
 input clk,rst,file_start,input [31:0] file_size,
 input native_thumb,
 input file_valid,input [7:0] file_byte,input [31:0] file_byte_offset,
 input file_end,input [7:0] upstream_error,
 output data_permit,output pixel_valid,input pixel_ready,output [31:0] pixel_rgb,
 output reg done,output [2:0] error,
 output [41:0] header_feed,input [196:0] header_result
);
 wire bytes_valid,bytes_ready,bytes_done,header_valid,raw_valid,raw_ready;
 wire [7:0] bytes_data;wire [31:0] bytes_offset;
 wire [15:0] w,h,px,py;wire [31:0] raw_rgb;
 wire decoder_done,scaler_done;
 // Two output slots break the coordinator/FIFO-ready path into the scaler.
 // Occupancy alone drives scaler_ready; no combinational downstream ready.
 wire scaler_valid,scaler_ready;
 wire [31:0] scaler_rgb;
 reg [31:0] pixel_slot[0:1];
 reg read_slot,write_slot;
 reg [1:0] pixel_count;
 reg raw_pipe_valid;
 reg [31:0] raw_pipe_rgb;
 wire native_mode=NATIVE_THUMB_ENABLE && native_thumb;
 wire push_pixel=(native_mode?raw_pipe_valid:scaler_valid) && scaler_ready;
 wire pop_pixel=pixel_valid && pixel_ready;
 assign scaler_ready=pixel_count<2;
 assign pixel_valid=pixel_count!=0;
 assign pixel_rgb=pixel_slot[read_slot];
 always @(posedge clk or posedge rst)begin
  if(rst)begin read_slot<=0;write_slot<=0;pixel_count<=0;end
  else if(file_start)begin read_slot<=0;write_slot<=0;pixel_count<=0;end
  else begin
   if(push_pixel)begin pixel_slot[write_slot]<=native_mode?raw_pipe_rgb:scaler_rgb;write_slot<=~write_slot;end
   if(pop_pixel)read_slot<=~read_slot;
   case({push_pixel,pop_pixel})
    2'b10:pixel_count<=pixel_count+1'b1;
    2'b01:pixel_count<=pixel_count-1'b1;
    default:;
   endcase
  end
 end
 reg decode_seen,scale_seen,reported;
 // Registered ready/valid boundary keeps decoder counters and coordinates
 // out of the scaler's row-selection cone.
 reg [15:0] raw_pipe_x,raw_pipe_y;
 wire scaler_in_ready;
 assign raw_ready=!raw_pipe_valid || (native_mode?scaler_ready:scaler_in_ready);
 always @(posedge clk or posedge rst)begin
  if(rst)begin raw_pipe_valid<=0;raw_pipe_rgb<=0;raw_pipe_x<=0;raw_pipe_y<=0;end
  else if(file_start)raw_pipe_valid<=0;
  else if(raw_ready)begin
   raw_pipe_valid<=raw_valid;
   if(raw_valid)begin raw_pipe_rgb<=raw_rgb;raw_pipe_x<=px;raw_pipe_y<=py;end
  end
 end
 bmp_sector_buffer buffer(
  .clk(clk),.rst(rst || file_start),.in_valid(file_valid),.in_byte(file_byte),
  .in_offset(file_byte_offset),.in_done(file_end),.data_permit(data_permit),
  .out_valid(bytes_valid),.out_ready(bytes_ready),.out_byte(bytes_data),
  .out_offset(bytes_offset),.out_done(bytes_done));
 // FETCH registers data one clock before PRESENT. The decoder can capture
 // the header address on that same FETCH edge without delaying consumption.
 wire [196:0] decoder_header_result;
 generate if(SHARED_HEADER)begin:g_shared_header
  assign decoder_header_result=header_result;
 end else begin:g_own_header
  // Fixed 640x480 dimensions are unused in range mode, as in bmp24_decoder.
  bmp_header_result_check #(.ALLOW_32(1),.RANGE_DIMENSIONS(1)) u_header(
   .clk(clk),.feed(header_feed),.bmp_width(16'd640),.bmp_height(16'd480),
   .result(decoder_header_result),.file_len());
 end endgenerate
 bmp24_decoder_core #(.ALLOW_32(1),.RANGE_DIMENSIONS(1),.FLOW_CONTROL(1),
                 .HEADER_OFFSET_LOOKAHEAD(1)) decoder(
  .clk(clk),.rst(rst),.expected_width(16'd0),.expected_height(16'd0),
  .file_start(file_start),.file_size(file_size),.file_valid(bytes_valid),
  .file_byte(bytes_data),.file_byte_offset(bytes_offset),.file_end(bytes_done),
  .upstream_error(upstream_error),.header_accepted(header_valid),.pixel_valid(raw_valid),
  .pixel_ready(raw_ready),.pixel_rgb(),.pixel_rgba(raw_rgb),.pixel_x(px),.pixel_y(py),
  .frame_commit(),.bmp_done(decoder_done),.bmp_error(error),.file_ready(bytes_ready),
  .image_width(w),.image_height(h),.header_feed(header_feed),.header_result(decoder_header_result));
 // Final TD03 measured raw_pipe_rgb[16] -> line BRAM at -0.020 ns.
 // Delay only that data bit, retaining both native and scaled cycle timing.
 wire [31:0] scale_input_rgb;
 assign scale_input_rgb[31:17]=raw_pipe_rgb[31:17];
 assign scale_input_rgb[15:0]=raw_pipe_rgb[15:0];
 (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_scale_data_hold(.o(scale_input_rgb[16]),.a(raw_pipe_rgb[16]));
 image_scale_nearest scaler(.clk(clk),.rst(rst || file_start),.start(header_valid && !native_mode),
  .image_width(w),.image_height(h),.in_valid(raw_pipe_valid && !native_mode),.in_ready(scaler_in_ready),
  .in_rgb(scale_input_rgb),.in_x(raw_pipe_x),.in_y(raw_pipe_y),.out_valid(scaler_valid),.out_ready(scaler_ready),
  .out_rgb(scaler_rgb),.done(scaler_done));
 always @(posedge clk or posedge rst)begin
  if(rst)begin done<=0;decode_seen<=0;scale_seen<=0;reported<=0;end
  else begin
   done<=0;
   if(file_start)begin decode_seen<=0;scale_seen<=0;reported<=0;end
   else begin
    if(decoder_done)decode_seen<=1;
    if(scaler_done)scale_seen<=1;
    if(!reported && error==0 && upstream_error==0 &&
       (decode_seen || decoder_done) && (native_mode?!raw_pipe_valid:scale_seen) && pixel_count==0)begin done<=1;reported<=1;end
   end
  end
 end
endmodule
