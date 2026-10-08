// Snapshot queue and ASCII serializer. No ready output: diagnostics never
// participate in the player's backpressure/commit/recovery handshakes.
module uart_event_logger #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE = 115200,
    parameter integer QUEUE_DEPTH = 8
)(
    input wire clk, rst,
    input wire [15:0] events,
    input wire [1:0] image_index,
    input wire [31:0] sector,
    input wire [2:0] error_code,
    input wire [3:0] phase,
    input wire auto_enabled,
    input wire [63:0] sd_debug,
    output wire uart_tx
);
localparam integer MS_CYCLES = CLK_FREQ_HZ / 1000;
localparam integer MS_BITS = MS_CYCLES > 1 ? $clog2(MS_CYCLES) : 1;
localparam integer PTR_BITS = $clog2(QUEUE_DEPTH);
localparam integer COUNT_BITS = $clog2(QUEUE_DEPTH+1);
localparam integer CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2) / BAUD_RATE;
reg [MS_BITS-1:0] ms_div;
reg [31:0] milliseconds;
always @(posedge clk or posedge rst) begin
    if(rst) begin ms_div<=0; milliseconds<=0; end
    else if(ms_div == MS_CYCLES-1) begin ms_div<=0; milliseconds<=milliseconds+1'b1; end
    else ms_div<=ms_div+1'b1;
end

// Delay enqueue one clock: SD diagnostic registers finish capturing a failure
// on the event edge. All other context is latched on that original edge.
reg [89:0] pending;
wire pending_valid = |pending[57:42];
always @(posedge clk or posedge rst) begin
    if(rst) pending<=0;
    else pending<={milliseconds,events,image_index,sector,error_code,phase,auto_enabled};
end
wire [63:0] event_debug = ((pending[50] && pending[7:5] == 3'd2) || pending[43]) ? sd_debug : 64'd0;
reg [153:0] queue [0:QUEUE_DEPTH-1];
reg [PTR_BITS-1:0] wr_ptr, rd_ptr;
reg [COUNT_BITS-1:0] count;
reg [31:0] dropped;
reg active, boot;
reg [153:0] snapshot;
reg [15:0] remaining;
wire pop = !boot && !active && (count != 0);
wire push = pending_valid && ((count < QUEUE_DEPTH) || pop);
wire lost = pending_valid && !push;
wire report_drop = !boot && !active && (count == 0) && (dropped != 0);
always @(posedge clk or posedge rst) begin
    if(rst) begin wr_ptr<=0; rd_ptr<=0; count<=0; dropped<=0; end
    else begin
        if(push) begin
            queue[wr_ptr]<={pending,event_debug};
            wr_ptr<=wr_ptr+1'b1;
        end
        if(pop) rd_ptr<=rd_ptr+1'b1;
        case({push,pop})
            2'b10: count<=count+1'b1;
            2'b01: count<=count-1'b1;
            default: ;
        endcase
        if(report_drop) dropped<=0;
        else if(lost) dropped<=dropped+1'b1;
    end
end

reg [6:0] char_index;
reg start, waiting;
wire done;
reg [3:0] kind;
integer k;
always @* begin
    kind=0;
    for(k=15;k>=0;k=k-1) if(remaining[k]) kind=k;
end
wire [15:0] rest = remaining & ~(16'b1 << kind);
function [79:0] event_name;
    input [3:0] value;
    begin
        case(value)
            0:event_name="INIT_OK   "; 1:event_name="INIT_FAIL ";
            2:event_name="SCAN_START"; 3:event_name="SCAN_DONE ";
            4:event_name="LOAD      "; 5:event_name="RETRY     ";
            6:event_name="SKIP      "; 7:event_name="COMMIT    ";
            8:event_name="ERROR     "; 9:event_name="RESCAN    ";
            10:event_name="MODE      "; 11:event_name="WAIT      ";
            12:event_name="NO_IMAGE  "; 13:event_name="STOP      ";
            14:event_name="RECOVERED "; default:event_name="DROP      ";
        endcase
    end
endfunction
function [7:0] hex;
    input [3:0] value;
    begin hex=(value<10) ? 8'h30+{4'd0,value} : 8'h41+{4'd0,value}-8'd10; end
endfunction
wire [79:0] name_text=event_name(kind);
localparam [175:0] BANNER="BOOT v0.5.4-s3-local.2";
reg [7:0] tx_data;
always @* begin
    tx_data=8'h20;
    if(boot) begin
        if(char_index<22) tx_data=BANNER[(21-char_index)*8 +: 8];
        else if(char_index==22) tx_data=8'h0d;
        else tx_data=8'h0a;
    end else begin
        if(char_index<10) tx_data=name_text[(9-char_index)*8 +: 8];
        else if(char_index>=13 && char_index<=20) tx_data=hex(snapshot[153-(char_index-13)*4 -: 4]);
        else if(char_index==24) tx_data=8'h30+{6'd0,snapshot[105:104]};
        else if(char_index>=28 && char_index<=35) tx_data=hex(snapshot[103-(char_index-28)*4 -: 4]);
        else if(char_index==39) tx_data=hex({1'b0,snapshot[71:69]});
        else if(char_index==43) tx_data=hex(snapshot[68:65]);
        else if(char_index==47) tx_data=8'h30+{7'd0,snapshot[64]};
        else if(char_index>=51 && char_index<=66) tx_data=hex(snapshot[63-(char_index-51)*4 -: 4]);
        else case(char_index)
            11:tx_data="T"; 12,23,27,38,42,46,50:tx_data="=";
            22:tx_data="I"; 26:tx_data="S"; 37:tx_data="E";
            41:tx_data="P"; 45:tx_data="A"; 49:tx_data="D";
            67:tx_data=8'h0d; 68:tx_data=8'h0a;
            default: ;
        endcase
    end
end
uart_tx_byte #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx(
    .clk(clk),.rst(rst),.start(start),.data(tx_data),
    .tx(uart_tx),.busy(),.done(done)
);
always @(posedge clk or posedge rst) begin
    if(rst) begin
        boot<=1; active<=0; snapshot<=0; remaining<=0;
        char_index<=0; start<=0; waiting<=0;
    end else begin
        start<=0;
        if(pop) begin
            snapshot<=queue[rd_ptr]; remaining<=queue[rd_ptr][121:106];
            active<=1; char_index<=0;
        end else if(report_drop) begin
            // DROP.S holds the number of discarded snapshots, not an SD sector.
            snapshot<={milliseconds,16'h8000,2'd0,dropped,3'd0,4'd0,1'b0,64'd0};
            remaining<=16'h8000; active<=1; char_index<=0;
        end
        if((boot || active) && !waiting) begin start<=1; waiting<=1; end
        else if(waiting && done) begin
            waiting<=0;
            if((boot && char_index==23) || (!boot && char_index==68)) begin
                char_index<=0;
                if(boot) boot<=0;
                else if(rest != 0) remaining<=rest;
                else active<=0;
            end else char_index<=char_index+1'b1;
        end
    end
end
endmodule
