// CR/LF line parser and bounded reply queue. Text byte zero is bits [7:0].
module subtitle_uart_controller(
    input clk, rst,
    input [7:0] rx_data,
    input rx_valid, rx_framing_error,
    output reg [119:0] cfg_text,
    output reg [3:0] cfg_length,
    output reg cfg_enable,
    output reg cfg_update_valid,
    output wire reply_valid,
    output reg [7:0] reply_data,
    output wire reply_last,
    input reply_ready
);
    localparam [119:0] DEFAULT_TEXT=120'h0000002041475046208c8b8b8a8389;
    // Bytes are validated and ASCII-lowercase folded once as they arrive.
    // Unreceived line bytes stay zero, so the text is line[127:32] directly.
    // lower[] keeps the command bytes 0..6 exact: folded==X && !lower is raw==X.
    reg [127:0] line;
    reg [6:0] lower;
    reg [4:0] length;
    reg bad_line, discard_lf, text_bad;
    reg [119:0] parsed;
    reg [3:0] parsed_length;
    reg parsed_enable, good, query;
    wire eol=rx_data==13 || rx_data==10;
    wire finish_line=rx_valid && eol && !(discard_lf && rx_data==10) &&
                     (length!=0 || bad_line);
    wire rx_lower=rx_data>="a" && rx_data<="z";
    wire rx_text_ok=(rx_data>=32 && rx_data<=126) || (rx_data>=128 && rx_data<=140);
    wire [7:0] rx_folded=rx_lower ? (rx_data & 8'hdf) : rx_data;
    always @* begin
        parsed=cfg_text; parsed_length=cfg_length; parsed_enable=cfg_enable;
        good=0; query=0;
        if(!bad_line && line[23:0]==24'h425553 && lower[2:0]==0) begin // SUB
            if(length==4 && line[31:24]=="?") begin good=1; query=1; end
            else if(length>=4 && line[31:24]=="=") begin
                good=1;
                if(length==6 && line[47:32]==16'h4e4f && lower[5:4]==0) parsed_enable=1; // ON
                else if(length==7 && line[55:32]==24'h46464f && lower[6:4]==0) parsed_enable=0;
                else if(length==6 && line[47:32]==16'h4e43 && lower[5:4]==0) begin
                    parsed=120'h0000000000000000008c8b8b8a8389; parsed_length=6;
                end else begin
                    parsed=line[127:32]; parsed_length=length-4;
                    // Validation used the original byte: folding ASCII lowercase
                    // cannot change whether a byte belongs to this set.
                    if(text_bad) good=0;
                end
            end
        end
    end
    // Reply descriptor captures the queried configuration, never a live bus.
    reg active, pending;
    reg [1:0] kind, pending_kind; // 0 OK, 1 ERR, 2 query
    // A pending query is promoted before any later line can change cfg: a
    // response arriving while one is pending and active becomes ERR. Its
    // snapshot is therefore taken from cfg at promotion.
    reg [124:0] snapshot;
    reg [5:0] index;
    wire response = finish_line;
    wire [1:0] response_kind = !good ? 1 : (query ? 2 : 0);
    wire [5:0] last_index=kind==2 ? 6'd10+{snapshot[123:120],1'b0} : (kind==1 ? 4 : 3);
    function [7:0] hex;
        input [3:0] n;
        begin hex=n<10 ? 8'd48+{4'd0,n} : 8'd55+{4'd0,n}; end
    endfunction
    reg [7:0] query_char, reply_raw;
    reg reply_hex;
    always @* begin
        reply_raw=10; query_char=0; reply_hex=0;
        if(kind==2) begin
            case(index)
                0:reply_raw="S"; 1:reply_raw="U"; 2:reply_raw="B"; 3:reply_raw="=";
                4:reply_raw=snapshot[124]?"1":"0"; 5:reply_raw=",";
                6:reply_raw="0";
                7:begin reply_raw={4'd0,snapshot[123:120]};reply_hex=1;end
                8:reply_raw=",";
                default:begin
                    if(index<last_index-1) begin
                        query_char=snapshot[((index-9)>>1)*8 +: 8];
                        reply_raw={4'd0,(index[0] ? query_char[7:4] : query_char[3:0])};reply_hex=1;
                    end else reply_raw=index==last_index-1 ? 13 : 10;
                end
            endcase
        end else if(kind==1) begin
            case(index) 0:reply_raw="E";1,2:reply_raw="R";3:reply_raw=13;default:reply_raw=10;endcase
        end else begin
            case(index) 0:reply_raw="O";1:reply_raw="K";2:reply_raw=13;default:reply_raw=10;endcase
        end
    end
    // Split snapshot selection from hex conversion. Prepare one character,
    // then hold the whole beat until accepted; index advances only on transfer.
    reg [7:0] prepared_data;
    reg prepared_hex, prepared_last, prepared_valid;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            prepared_data<=0;prepared_hex<=0;prepared_last<=0;prepared_valid<=0;
        end else if(reply_valid && reply_ready) prepared_valid<=0;
        else if(active && !prepared_valid) begin
            prepared_data<=reply_raw;prepared_hex<=reply_hex;
            prepared_last<=index==last_index;prepared_valid<=1;
        end
    end
    always @* reply_data=prepared_hex ? hex(prepared_data[3:0]) : prepared_data;
    assign reply_valid=active && prepared_valid;
    assign reply_last=prepared_last;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            cfg_text<=DEFAULT_TEXT; cfg_length<=12; cfg_enable<=1; cfg_update_valid<=0;
            line<=0; lower<=0; length<=0; bad_line<=0; discard_lf<=0; text_bad<=0;
            active<=0; pending<=0; kind<=0; pending_kind<=0;
            snapshot<=0; index<=0;
        end else begin
            cfg_update_valid<=0;
            if(rx_framing_error) bad_line<=1;
            if(rx_valid) begin
                if(discard_lf && rx_data==10) discard_lf<=0;
                else if(eol) begin
                    discard_lf<=rx_data==13; length<=0; line<=0; lower<=0; bad_line<=0; text_bad<=0;
                    if(finish_line && good && !query) begin
                        cfg_text<=parsed; cfg_length<=parsed_length; cfg_enable<=parsed_enable;
                        cfg_update_valid<=1;
                    end
                end else begin
                    discard_lf<=0;
                    if(length<16) begin
                        line[length*8 +: 8]<=rx_folded; length<=length+1'b1;
                        if(length<7) lower[length]<=rx_lower;
                        if(length>=4 && !rx_text_ok) text_bad<=1;
                    end
                    else bad_line<=1;
                end
            end
            if(reply_valid && reply_ready) begin
                if(reply_last) begin active<=0;index<=0;end
                else index<=index+1'b1;
            end
            if(!active && pending) begin
                active<=1;kind<=pending_kind;snapshot<={cfg_enable,cfg_length,cfg_text};index<=0;pending<=0;
            end
            if(response) begin
                if(!active && !pending) begin
                    active<=1;kind<=response_kind;snapshot<={cfg_enable,cfg_length,cfg_text};index<=0;
                end else begin
                    pending<=1;
                    pending_kind<=pending && active ? 1 : response_kind;
                end
            end
        end
    end
endmodule
