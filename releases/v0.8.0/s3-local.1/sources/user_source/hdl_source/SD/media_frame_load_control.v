`timescale 1ns/1ps
// SD-domain adapter: parser and memory completion are a single drained result.
// Ordinary failure cancels only the file, retaining the FAT32 volume geometry.
module media_frame_load_control #(parameter USE_FRAME_RESULT=1)(
 input clk,rst,
 input load_request, output load_accept,
 output load_result_valid, load_success, load_timeout,
 input load_result_ready, cancel_request, output reg cancel_ack,
 input parser_ready, source_done, source_error, input [2:0] source_error_code,
 output reg load_start, output parser_cancel,
 input write_req, write_req_ack, write_finish_toggle,
 input frame_error_toggle, input [2:0] frame_memory_error,
 output write_cancel_req, input write_cancel_ack,
 output reg fault_event, output reg [2:0] fault_code,
 output memory_fault, output [2:0] memory_code,
 output source_complete, write_complete
);
 localparam IDLE=0,WAIT_FRAME=1,DRAIN=2,RELEASE=3,RESULT=4;
 reg [2:0] state;
 reg [1:0] req_ack_sync,cancel_ack_sync;
 reg [2:0] finish_sync,error_sync,code0,code1;
 reg epoch,source_seen,finish_seen,core_cancelled,result_ok,result_timeout;
 wire finish_pulse=finish_sync[2]^finish_sync[1];
 assign memory_fault=USE_FRAME_RESULT && (error_sync[2]^error_sync[1]);
 assign memory_code=code1;
 assign load_accept=load_request && state==IDLE && parser_ready &&
                    !cancel_request && !cancel_ack_sync[1] && !req_ack_sync[1];
 assign load_result_valid=state==RESULT && !cancel_request;
 assign load_success=result_ok;
 assign load_timeout=result_timeout;
 assign parser_cancel=(state==DRAIN || state==RELEASE || cancel_request);
 assign write_cancel_req=state==DRAIN;
 assign source_complete=source_seen || source_done;
 assign write_complete=finish_seen || (epoch && !req_ack_sync[1] && finish_pulse);
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   state<=IDLE;req_ack_sync<=0;cancel_ack_sync<=0;finish_sync<=0;error_sync<=0;code0<=0;code1<=0;
   epoch<=0;source_seen<=0;finish_seen<=0;core_cancelled<=0;result_ok<=0;result_timeout<=0;
   load_start<=0;cancel_ack<=0;fault_event<=0;fault_code<=0;
  end else begin
   req_ack_sync<={req_ack_sync[0],write_req_ack};
   cancel_ack_sync<={cancel_ack_sync[0],write_cancel_ack};
   finish_sync<={finish_sync[1:0],write_finish_toggle};
   error_sync<={error_sync[1:0],frame_error_toggle};code0<=frame_memory_error;code1<=code0;
   load_start<=0;cancel_ack<=0;fault_event<=0;
   if(cancel_request && !core_cancelled) begin
    core_cancelled<=1;state<=DRAIN;epoch<=0;result_ok<=0;
   end else case(state)
    IDLE: begin
     if(!cancel_request) core_cancelled<=0;
     if(load_accept) begin
      load_start<=1;source_seen<=0;finish_seen<=0;epoch<=0;
      result_ok<=0;result_timeout<=0;state<=WAIT_FRAME;
     end
    end
    WAIT_FRAME: begin
     if(write_req && req_ack_sync[1]) epoch<=1;
     if(source_done) source_seen<=1;
     if(epoch && !req_ack_sync[1] && finish_pulse) finish_seen<=1;
     if(source_error || memory_fault) begin
      result_ok<=0;
      result_timeout<=(source_error && source_error_code==2) || (memory_fault && code1==3);
      fault_event<=1;fault_code<=memory_fault ? (code1==3 ? 3'd2 : 3'd3) : source_error_code;
      epoch<=0;state<=DRAIN;
     end else if(source_complete && write_complete) begin
      result_ok<=1;state<=RESULT;epoch<=0;
     end
    end
    DRAIN: if(cancel_ack_sync[1] && parser_ready) state<=RELEASE;
    RELEASE: if(!cancel_ack_sync[1] && !req_ack_sync[1] && parser_ready) begin
     if(core_cancelled) begin cancel_ack<=1;state<=IDLE;end
     else state<=RESULT;
    end
    RESULT: if(load_result_ready) state<=IDLE;
    default: state<=IDLE;
   endcase
  end
 end
endmodule
