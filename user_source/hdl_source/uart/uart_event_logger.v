// Snapshot queue and ASCII serializer. No ready output: diagnostics never
// participate in the player's backpressure/commit/recovery handshakes.
module uart_event_logger #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE = 115200,
    parameter integer QUEUE_DEPTH = 8,
    parameter integer REPLY_ENABLE = 0
)(
    input wire clk, rst,
    input wire [15:0] events,
    input wire [1:0] image_index,
    input wire [31:0] sector,
    input wire [2:0] error_code,
    input wire [3:0] phase,
    input wire auto_enabled,
    input wire [63:0] sd_debug,
    output wire uart_tx,
    input wire reply_valid,
    input wire [7:0] reply_data,
    input wire reply_last,
    output wire reply_ready
);
localparam integer MS_CYCLES = CLK_FREQ_HZ / 1000;
localparam integer MS_BITS = MS_CYCLES > 1 ? $clog2(MS_CYCLES) : 1;
// Keep QUEUE_DEPTH usable records in a twice-sized BRAM ring. At full
// occupancy, simultaneous read/write addresses remain distinct.
localparam integer PTR_BITS = $clog2(2*QUEUE_DEPTH);
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
reg [153:0] queue [0:2*QUEUE_DEPTH-1]; /* fehdl force_ram=1, ram_style="bram" */
reg [153:0] queue_read;
reg [PTR_BITS-1:0] wr_ptr, rd_ptr;
reg [COUNT_BITS-1:0] count;
reg [31:0] dropped;
reg active, boot, loading;
reg [153:0] snapshot;
reg [15:0] remaining;
reg reply_owner, reply_wait, reply_start, reply_end;
reg [7:0] reply_byte;
wire pop = !boot && !active && !loading && !reply_owner && (count != 0);
wire push = pending_valid && ((count < QUEUE_DEPTH) || pop);
wire lost = pending_valid && !push;
wire report_drop = !boot && !active && !loading && !reply_owner && (count == 0) && (dropped != 0);
// Synchronous read without reset allows BRAM inference. The loading state
// transfers this word to the serializer before active is asserted.
always @(posedge clk) begin
    if(push) queue[wr_ptr]<={pending,event_debug};
    if(pop) queue_read<=queue[rd_ptr];
end
always @(posedge clk or posedge rst) begin
    if(rst) begin wr_ptr<=0; rd_ptr<=0; count<=0; dropped<=0; end
    else begin
        if(push) begin
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
function [7:0] hex;
    input [3:0] value;
    begin hex=(value<10) ? 8'h30+{4'd0,value} : 8'h41+{4'd0,value}-8'd10; end
endfunction
// Event names (10 characters each) and the "BOOT v0.5.4-s3-local.2" banner
// live in one BRAM ROM at {text_sel, char_index}. It is read on the same edge
// that registers prepared_data, so every character keeps its original cycle.
// New cache records share WAIT's reserved phase codes; all old IDs, fields,
// queue framing and DROP semantics remain unchanged.
reg [7:0] text_rom [0:1023];
initial begin
    text_rom[0]=8'h49; text_rom[1]=8'h4e; text_rom[2]=8'h49; text_rom[3]=8'h54; text_rom[4]=8'h5f; text_rom[5]=8'h4f; text_rom[6]=8'h4b; text_rom[7]=8'h20; text_rom[8]=8'h20; text_rom[9]=8'h20;
    text_rom[32]=8'h49; text_rom[33]=8'h4e; text_rom[34]=8'h49; text_rom[35]=8'h54; text_rom[36]=8'h5f; text_rom[37]=8'h46; text_rom[38]=8'h41; text_rom[39]=8'h49; text_rom[40]=8'h4c; text_rom[41]=8'h20;
    text_rom[64]=8'h53; text_rom[65]=8'h43; text_rom[66]=8'h41; text_rom[67]=8'h4e; text_rom[68]=8'h5f; text_rom[69]=8'h53; text_rom[70]=8'h54; text_rom[71]=8'h41; text_rom[72]=8'h52; text_rom[73]=8'h54;
    text_rom[96]=8'h53; text_rom[97]=8'h43; text_rom[98]=8'h41; text_rom[99]=8'h4e; text_rom[100]=8'h5f; text_rom[101]=8'h44; text_rom[102]=8'h4f; text_rom[103]=8'h4e; text_rom[104]=8'h45; text_rom[105]=8'h20;
    text_rom[128]=8'h4c; text_rom[129]=8'h4f; text_rom[130]=8'h41; text_rom[131]=8'h44; text_rom[132]=8'h20; text_rom[133]=8'h20; text_rom[134]=8'h20; text_rom[135]=8'h20; text_rom[136]=8'h20; text_rom[137]=8'h20;
    text_rom[160]=8'h52; text_rom[161]=8'h45; text_rom[162]=8'h54; text_rom[163]=8'h52; text_rom[164]=8'h59; text_rom[165]=8'h20; text_rom[166]=8'h20; text_rom[167]=8'h20; text_rom[168]=8'h20; text_rom[169]=8'h20;
    text_rom[192]=8'h53; text_rom[193]=8'h4b; text_rom[194]=8'h49; text_rom[195]=8'h50; text_rom[196]=8'h20; text_rom[197]=8'h20; text_rom[198]=8'h20; text_rom[199]=8'h20; text_rom[200]=8'h20; text_rom[201]=8'h20;
    text_rom[224]=8'h43; text_rom[225]=8'h4f; text_rom[226]=8'h4d; text_rom[227]=8'h4d; text_rom[228]=8'h49; text_rom[229]=8'h54; text_rom[230]=8'h20; text_rom[231]=8'h20; text_rom[232]=8'h20; text_rom[233]=8'h20;
    text_rom[256]=8'h45; text_rom[257]=8'h52; text_rom[258]=8'h52; text_rom[259]=8'h4f; text_rom[260]=8'h52; text_rom[261]=8'h20; text_rom[262]=8'h20; text_rom[263]=8'h20; text_rom[264]=8'h20; text_rom[265]=8'h20;
    text_rom[288]=8'h52; text_rom[289]=8'h45; text_rom[290]=8'h53; text_rom[291]=8'h43; text_rom[292]=8'h41; text_rom[293]=8'h4e; text_rom[294]=8'h20; text_rom[295]=8'h20; text_rom[296]=8'h20; text_rom[297]=8'h20;
    text_rom[320]=8'h4d; text_rom[321]=8'h4f; text_rom[322]=8'h44; text_rom[323]=8'h45; text_rom[324]=8'h20; text_rom[325]=8'h20; text_rom[326]=8'h20; text_rom[327]=8'h20; text_rom[328]=8'h20; text_rom[329]=8'h20;
    text_rom[352]=8'h57; text_rom[353]=8'h41; text_rom[354]=8'h49; text_rom[355]=8'h54; text_rom[356]=8'h20; text_rom[357]=8'h20; text_rom[358]=8'h20; text_rom[359]=8'h20; text_rom[360]=8'h20; text_rom[361]=8'h20;
    text_rom[384]=8'h4e; text_rom[385]=8'h4f; text_rom[386]=8'h5f; text_rom[387]=8'h49; text_rom[388]=8'h4d; text_rom[389]=8'h41; text_rom[390]=8'h47; text_rom[391]=8'h45; text_rom[392]=8'h20; text_rom[393]=8'h20;
    text_rom[416]=8'h53; text_rom[417]=8'h54; text_rom[418]=8'h4f; text_rom[419]=8'h50; text_rom[420]=8'h20; text_rom[421]=8'h20; text_rom[422]=8'h20; text_rom[423]=8'h20; text_rom[424]=8'h20; text_rom[425]=8'h20;
    text_rom[448]=8'h52; text_rom[449]=8'h45; text_rom[450]=8'h43; text_rom[451]=8'h4f; text_rom[452]=8'h56; text_rom[453]=8'h45; text_rom[454]=8'h52; text_rom[455]=8'h45; text_rom[456]=8'h44; text_rom[457]=8'h20;
    text_rom[480]=8'h44; text_rom[481]=8'h52; text_rom[482]=8'h4f; text_rom[483]=8'h50; text_rom[484]=8'h20; text_rom[485]=8'h20; text_rom[486]=8'h20; text_rom[487]=8'h20; text_rom[488]=8'h20; text_rom[489]=8'h20;
    text_rom[512]=8'h43; text_rom[513]=8'h41; text_rom[514]=8'h43; text_rom[515]=8'h48; text_rom[516]=8'h45; text_rom[517]=8'h5f; text_rom[518]=8'h44; text_rom[519]=8'h4f; text_rom[520]=8'h4e; text_rom[521]=8'h45;
    text_rom[544]=8'h43; text_rom[545]=8'h41; text_rom[546]=8'h43; text_rom[547]=8'h48; text_rom[548]=8'h45; text_rom[549]=8'h5f; text_rom[550]=8'h48; text_rom[551]=8'h49; text_rom[552]=8'h54; text_rom[553]=8'h20;
    text_rom[576]=8'h42; text_rom[577]=8'h4f; text_rom[578]=8'h4f; text_rom[579]=8'h54; text_rom[580]=8'h20; text_rom[581]=8'h76; text_rom[582]=8'h30; text_rom[583]=8'h2e; text_rom[584]=8'h35; text_rom[585]=8'h2e; text_rom[586]=8'h34;
    text_rom[587]=8'h2d; text_rom[588]=8'h73; text_rom[589]=8'h33; text_rom[590]=8'h2d; text_rom[591]=8'h6c; text_rom[592]=8'h6f; text_rom[593]=8'h63; text_rom[594]=8'h61; text_rom[595]=8'h6c; text_rom[596]=8'h2e; text_rom[597]=8'h32;
end
wire [4:0] text_sel = boot ? 5'd18 :
                      (kind==11 && snapshot[68:65]==4'hc) ? 5'd16 :
                      (kind==11 && snapshot[68:65]==4'hd) ? 5'd17 : {1'b0,kind};
wire text_char = boot ? char_index<22 : char_index<10;
reg [7:0] text_q;
always @(posedge clk) text_q <= text_rom[{text_sel,char_index[4:0]}];
reg [7:0] tx_data;
reg tx_hex;
// Select inside each field, not across the entire 154-bit snapshot. The
// enclosing character ranges guarantee these modulo indices are exact.
wire [31:0] time_field = snapshot[153:122];
wire [31:0] sector_field = snapshot[103:72];
wire [63:0] debug_field = snapshot[63:0];
wire [2:0] time_nibble = 3'd4 - char_index[2:0];
wire [2:0] sector_nibble = 3'd3 - char_index[2:0];
wire [3:0] debug_nibble = 4'd2 - char_index[3:0];
always @* begin
    tx_data=8'h20;
    tx_hex=1'b0;
    if(boot) begin
        if(char_index==22) tx_data=8'h0d;
        else if(char_index>22) tx_data=8'h0a;
    end else begin
        if(char_index>=13 && char_index<=20) begin tx_data={4'd0,time_field[{time_nibble,2'b00} +: 4]};tx_hex=1;end
        else if(char_index==24) tx_data=8'h30+{6'd0,snapshot[105:104]};
        else if(char_index>=28 && char_index<=35) begin tx_data={4'd0,sector_field[{sector_nibble,2'b00} +: 4]};tx_hex=1;end
        else if(char_index==39) begin tx_data={5'd0,snapshot[71:69]};tx_hex=1;end
        else if(char_index==43) begin tx_data={4'd0,snapshot[68:65]};tx_hex=1;end
        else if(char_index==47) tx_data=8'h30+{7'd0,snapshot[64]};
        else if(char_index>=51 && char_index<=66) begin tx_data={4'd0,debug_field[{debug_nibble,2'b00} +: 4]};tx_hex=1;end
        else case(char_index)
            11:tx_data="T"; 12,23,27,38,42,46,50:tx_data="=";
            22:tx_data="I"; 26:tx_data="S"; 37:tx_data="E";
            41:tx_data="P"; 45:tx_data="A"; 49:tx_data="D";
            67:tx_data=8'h0d; 68:tx_data=8'h0a;
            default: ;
        endcase
    end
end
// Field selection is stable before registered start is consumed. Register
// raw characters/nibbles before hexadecimal conversion and serial framing.
reg [7:0] prepared_data;
reg prepared_hex, prepared_text;
always @(posedge clk or posedge rst) begin
    if(rst) begin prepared_data<=8'h20;prepared_hex<=0;prepared_text<=0;end
    else begin prepared_data<=tx_data;prepared_hex<=tx_hex;prepared_text<=text_char;end
end
uart_tx_byte #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx(
    .clk(clk),.rst(rst),.start(start || reply_start),
    .data(reply_owner ? reply_byte : (prepared_hex ? hex(prepared_data[3:0]) : (prepared_text ? text_q : prepared_data))),
    .tx(uart_tx),.busy(),.done(done)
);
// Acquire only between complete log records; keep ownership through reply LF.
assign reply_ready = REPLY_ENABLE && reply_owner && !reply_wait;
always @(posedge clk or posedge rst) begin
    if(rst) begin reply_owner<=0;reply_wait<=0;reply_start<=0;reply_end<=0;reply_byte<=0;end
    else begin
        reply_start<=0;
        if(REPLY_ENABLE && !reply_owner && !boot && !active && !loading && count==0 &&
           dropped==0 && !pending_valid && reply_valid) reply_owner<=1;
        if(reply_ready && reply_valid) begin
            reply_byte<=reply_data; reply_end<=reply_last; reply_start<=1;reply_wait<=1;
        end else if(reply_owner && reply_wait && done) begin
            reply_wait<=0;
            if(reply_end) reply_owner<=0;
        end
    end
end
always @(posedge clk or posedge rst) begin
    if(rst) begin
        boot<=1; active<=0; loading<=0; snapshot<=0; remaining<=0;
        char_index<=0; start<=0; waiting<=0;
    end else begin
        start<=0;
        loading<=pop;
        if(loading) begin
            snapshot<=queue_read; remaining<=queue_read[121:106];
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
