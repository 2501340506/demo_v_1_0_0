module bmp_scale_stream (
 input clk,rst,file_start,input [31:0] file_size,
 input file_valid,input [7:0] file_byte,input [31:0] file_byte_offset,
 input file_end,input [7:0] upstream_error,
 output data_permit,output pixel_valid,input pixel_ready,output [23:0] pixel_rgb,
 output reg done,output [2:0] error
);
 wire bytes_valid,bytes_ready,bytes_done,header_valid,raw_valid,raw_ready;
 wire [7:0] bytes_data;wire [31:0] bytes_offset;
 wire [15:0] w,h,px,py;wire [23:0] raw_rgb;
 wire decoder_done,scaler_done;
 // Two output slots break the coordinator/FIFO-ready path into the scaler.
 // Occupancy alone drives scaler_ready; no combinational downstream ready.
 wire scaler_valid,scaler_ready;
 wire [23:0] scaler_rgb;
 reg [23:0] pixel_slot[0:1];
 reg read_slot,write_slot;
 reg [1:0] pixel_count;
 wire push_pixel=scaler_valid && scaler_ready;
 wire pop_pixel=pixel_valid && pixel_ready;
 assign scaler_ready=pixel_count<2;
 assign pixel_valid=pixel_count!=0;
 assign pixel_rgb=pixel_slot[read_slot];
 always @(posedge clk or posedge rst)begin
  if(rst)begin read_slot<=0;write_slot<=0;pixel_count<=0;end
  else if(file_start)begin read_slot<=0;write_slot<=0;pixel_count<=0;end
  else begin
   if(push_pixel)begin pixel_slot[write_slot]<=scaler_rgb;write_slot<=~write_slot;end
   if(pop_pixel)read_slot<=~read_slot;
   case({push_pixel,pop_pixel})
    2'b10:pixel_count<=pixel_count+1'b1;
    2'b01:pixel_count<=pixel_count-1'b1;
    default:;
   endcase
  end
 end
 reg decode_seen,scale_seen,reported;
 bmp_sector_buffer buffer(
  .clk(clk),.rst(rst || file_start),.in_valid(file_valid),.in_byte(file_byte),
  .in_offset(file_byte_offset),.in_done(file_end),.data_permit(data_permit),
  .out_valid(bytes_valid),.out_ready(bytes_ready),.out_byte(bytes_data),
  .out_offset(bytes_offset),.out_done(bytes_done));
 bmp24_decoder #(.ALLOW_32(0),.RANGE_DIMENSIONS(1),.FLOW_CONTROL(1)) decoder(
  .clk(clk),.rst(rst),.expected_width(16'd0),.expected_height(16'd0),
  .file_start(file_start),.file_size(file_size),.file_valid(bytes_valid),
  .file_byte(bytes_data),.file_byte_offset(bytes_offset),.file_end(bytes_done),
  .upstream_error(upstream_error),.header_accepted(header_valid),.pixel_valid(raw_valid),
  .pixel_ready(raw_ready),.pixel_rgb(raw_rgb),.pixel_x(px),.pixel_y(py),
  .frame_commit(),.bmp_done(decoder_done),.bmp_error(error),.file_ready(bytes_ready),
  .image_width(w),.image_height(h));
 image_scale_nearest scaler(.clk(clk),.rst(rst || file_start),.start(header_valid),
  .image_width(w),.image_height(h),.in_valid(raw_valid),.in_ready(raw_ready),
  .in_rgb(raw_rgb),.in_x(px),.in_y(py),.out_valid(scaler_valid),.out_ready(scaler_ready),
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
       (decode_seen || decoder_done) && scale_seen && pixel_count==0)begin done<=1;reported<=1;end
   end
  end
 end
endmodule
