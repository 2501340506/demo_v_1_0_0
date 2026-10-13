`timescale 1ns/1ps
// Old/new subtitle_uart_controller: random command lines, all outputs every cycle.
module tb_subtitle_parser_equiv;
 reg clk=0, rst=1, rx_valid=0, framing=0, ready=0;
 reg [7:0] rx_data=0;
 always #5 clk=~clk;
 wire [119:0] r_text, n_text; wire [3:0] r_len, n_len;
 wire r_en, n_en, r_upd, n_upd, r_v, n_v, r_last, n_last; wire [7:0] r_data, n_data;
 subtitle_uart_controller_ref rref(.clk(clk),.rst(rst),.rx_data(rx_data),.rx_valid(rx_valid),.rx_framing_error(framing),
  .cfg_text(r_text),.cfg_length(r_len),.cfg_enable(r_en),.cfg_update_valid(r_upd),
  .reply_valid(r_v),.reply_data(r_data),.reply_last(r_last),.reply_ready(ready));
 subtitle_uart_controller rnew(.clk(clk),.rst(rst),.rx_data(rx_data),.rx_valid(rx_valid),.rx_framing_error(framing),
  .cfg_text(n_text),.cfg_length(n_len),.cfg_enable(n_en),.cfg_update_valid(n_upd),
  .reply_valid(n_v),.reply_data(n_data),.reply_last(n_last),.reply_ready(ready));
 integer cycle=0, errors=0, lines=0, updates=0, queries=0, errs=0, oks=0, replies=0, resets=0;
 integer ready_mode=0;
 always @(negedge clk) begin
  if({r_text,r_len,r_en,r_upd,r_v,r_data,r_last}!=={n_text,n_len,n_en,n_upd,n_v,n_data,n_last}) begin
   errors++; if(errors<10) $display("MISMATCH cycle=%0d upd=%b/%b v=%b/%b data=%h/%h len=%0d/%0d",cycle,r_upd,n_upd,r_v,n_v,r_data,n_data,r_len,n_len);
  end
  if(r_upd) updates++;
  if(r_v && ready) begin replies++; if(r_last) begin
   case(rref.kind) 2: queries++; 1: errs++; default: oks++; endcase end end
 end
 always @(posedge clk) begin
  cycle<=cycle+1; #1;
  ready = ready_mode==0 ? 1 : ready_mode==1 ? ($urandom%3!=0) : ($urandom%50==0);
 end
 function automatic [7:0] text_byte();
  case($urandom%10)
   0: text_byte=$urandom%32;                 // control (invalid)
   1: text_byte=127+$urandom%2;              // 127 invalid, 128 valid
   2: text_byte=128+$urandom%16;             // 128..140 valid, 141..143 invalid
   3: text_byte=141+$urandom%115;            // invalid high
   4,5: text_byte="a"+$urandom%26;
   6: text_byte="A"+$urandom%26;
   default: text_byte=32+$urandom%95;
  endcase
  if(text_byte==10 || text_byte==13) text_byte=" ";
 endfunction
 task automatic put(input [7:0] b);
  begin
   @(negedge clk); rx_valid=1; rx_data=b; framing=($urandom%400==0);
   @(negedge clk); rx_valid=0; framing=0;
   repeat($urandom%3) @(negedge clk);
  end
 endtask
 task automatic put_str(input string s);
  for(int i=0;i<s.len();i++) put(s[i]);
 endtask
 task automatic one_line();
  string head; int n;
  begin
   case($urandom%8)
    0: head="sub"; 1: head="SuB"; 2: head="SUC"; default: head="SUB";
   endcase
   if($urandom%20==0) head="";
   put_str(head);
   case($urandom%10)
    0: put("?");
    1: begin put("?"); put("x"); end
    2: put_str("=ON"); 3: put_str("=on"); 4: put_str("=OFF"); 5: put_str("=oFf");
    6: put_str($urandom%2 ? "=NC" : "=nc");
    7: put_str($urandom%2 ? "=ONX" : "=OF");
    default: begin
     if($urandom%8) put("="); else put("-");
     n=($urandom%6==0) ? 10+$urandom%10 : $urandom%13;
     for(int i=0;i<n;i++) put(text_byte());
    end
   endcase
   case($urandom%6)
    0: put(13); 1: begin put(13); put(10); end 2: begin put(10); put(13); end
    3: begin put(13); put(10); put(10); end
    default: put(10);
   endcase
   if($urandom%15==0) put(10);
   lines++;
  end
 endtask
 initial begin
  repeat(3) @(negedge clk); rst=0;
  for(int k=0;k<20000;k++) begin
   if(k%1500==0) ready_mode=$urandom%3;
   if(k%2500==0) ready_mode=0;
   one_line();
   if($urandom%3000==0) begin rst=1; resets++; repeat(2) @(negedge clk); rst=0; end
  end
  ready_mode=0; repeat(2000) @(negedge clk);
  if(updates<1000 || queries<200 || errs<1000 || oks<1000 || resets<2)
   $display("** Error: insufficient coverage updates=%0d queries=%0d err=%0d ok=%0d resets=%0d",updates,queries,errs,oks,resets);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS subtitle parser equivalence lines=%0d cfg_updates=%0d replies: query=%0d ok=%0d err=%0d bytes=%0d resets=%0d",lines,updates,queries,oks,errs,replies,resets);
  $finish;
 end
endmodule
