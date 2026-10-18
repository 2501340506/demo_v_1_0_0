// Streaming VFAT name matcher. No sector buffer or generated 8.3 aliases.
// Slot 0/1: Chinese scene/publicity parents; 2..5: disaster directories.
module fat32_lfn_directories(
 input clk,rst,clear,byte_valid,input [4:0] byte_index,input [7:0] byte_data,
 output reg [5:0] directory_match,output reg [31:0] directory_cluster
);
 reg [7:0] ordinal,attribute,checksum,sfn_sum,pair_low,chain_checksum;
 reg [5:0] entry_match,chain_match;
 reg [1:0] expected;
 reg entry_ok;
 reg [31:0] cluster;
 reg character_high;
 integer k;
 function [4:0] name_length;
  input integer slot;
  begin case(slot) 0,1:name_length=4;2:name_length=17;3:name_length=14;default:name_length=13;endcase end
 endfunction
 // Decode the fixed UTF-16 names on the low-byte cycle. The next
 // high byte compares against registered constants, including byte 31.
 reg [95:0] expected_characters;
 function [95:0] character_constants;
 input [5:0] address;
 begin
 case(address)
 6'd1:character_constants=96'h007100660064006c5ba360c5;
 6'd3:character_constants=96'h0075006c006500618bb2666f;
 6'd5:character_constants=96'h0061006f0062006e6a216a21;
 6'd7:character_constants=96'h006b006f007200645f0f5f0f;
 6'd9:character_constants=96'h006500640069007300000000;
 6'd14:character_constants=96'h005f005f0073006cffffffff;
 6'd16:character_constants=96'h00760076005f0069ffffffff;
 6'd18:character_constants=96'h0069006900760064ffffffff;
 6'd20:character_constants=96'h006c006c00690065ffffffff;
 6'd22:character_constants=96'h006c006c006c005fffffffff;
 6'd24:character_constants=96'h00610061006c0076ffffffff;
 6'd28:character_constants=96'h0067006700610069ffffffff;
 6'd30:character_constants=96'h006500650067006cffffffff;
 6'd33:character_constants=96'h000000000065006cffffffff;
 6'd35:character_constants=96'hffffffff00000061ffffffff;
 6'd37:character_constants=96'hffffffffffff0067ffffffff;
 6'd39:character_constants=96'hffffffffffff0065ffffffff;
 6'd41:character_constants=96'hffffffffffff0000ffffffff;
 6'd46:character_constants=96'hffffffffffffffffffffffff;
 6'd48:character_constants=96'hffffffffffffffffffffffff;
 6'd50:character_constants=96'hffffffffffffffffffffffff;
 6'd52:character_constants=96'hffffffffffffffffffffffff;
 6'd54:character_constants=96'hffffffffffffffffffffffff;
 6'd56:character_constants=96'hffffffffffffffffffffffff;
 6'd60:character_constants=96'hffffffffffffffffffffffff;
 6'd62:character_constants=96'hffffffffffffffffffffffff;
 default:character_constants=96'hffffffffffffffffffffffff;
 endcase
 end
 endfunction
 always @* begin
 case(byte_index)
 2,4,6,8,10,15,17,19,21,23,25,29,31:character_high=1;
 default:character_high=0;
 endcase
 end
 wire char_byte=(byte_index>=1 && byte_index<=10) || (byte_index>=14 && byte_index<=25) || byte_index>=28;
 wire [15:0] character={byte_data,pair_low};
 // Keep the expected tuple on both bytes of each UTF-16 character.
 // Updating without byte_valid removes the shared sector-valid CE from
 // this constant ROM; gaps and consecutive bytes retain the same compare.
 wire [4:0] character_low_index=character_high?byte_index-1'b1:byte_index;
 always @(posedge clk)
  expected_characters<=character_constants({ordinal[4:0]==2,character_low_index});
 reg [5:0] compared;
 always @* begin
  compared=entry_match;
  for(integer i=0;i<6;i=i+1)
   if(character!=expected_characters[i*16+:16])compared[i]=0;
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   ordinal<=0;attribute<=0;checksum<=0;sfn_sum<=0;pair_low<=0;chain_checksum<=0;
   entry_match<=0;chain_match<=0;expected<=3;entry_ok<=0;cluster<=0;
   directory_match<=0;directory_cluster<=0;
  end else begin
   directory_match<=0;
   if(clear)begin chain_match<=0;expected<=3;entry_match<=0;end
   else if(byte_valid)begin
    if(byte_index==0)begin
     ordinal<=byte_data;entry_match<=6'b111111;entry_ok<=!byte_data[7] && !byte_data[5] && (byte_data[4:0]==1 || byte_data[4:0]==2);
     sfn_sum<=byte_data;cluster<=0;
    end else if(byte_index<=10)sfn_sum<={sfn_sum[0],sfn_sum[7:1]}+byte_data;
    if(char_byte)begin
     if(!character_high)begin
      pair_low<=byte_data;
     end
     else entry_match<=compared;
    end
    case(byte_index)
     11:attribute<=byte_data;
     12:if(byte_data!=0)entry_ok<=0;
     13:checksum<=byte_data;
     20:cluster[23:16]<=byte_data;
     21:cluster[31:24]<=byte_data;
     26:begin cluster[7:0]<=byte_data;if(byte_data!=0)entry_ok<=0;end
     27:begin cluster[15:8]<=byte_data;if(byte_data!=0)entry_ok<=0;end
     31:begin
      if(attribute==8'h0f)begin
       if(!entry_ok)begin chain_match<=0;expected<=3;end
       else if(ordinal[6])begin
        for(k=0;k<6;k=k+1)
         chain_match[k]<=compared[k] && ordinal[4:0]==(name_length(k)>13?2:1);
        chain_checksum<=checksum;expected<=ordinal[1:0]-1'b1;
       end else if(expected!=0 && ordinal[4:0]=={3'b000,expected} && checksum==chain_checksum)begin
        chain_match<=chain_match & compared;expected<=expected-1'b1;
       end else begin chain_match<=0;expected<=3;end
      end else begin
       if(expected==0 && chain_checksum==sfn_sum && attribute[4] && !attribute[3] && ordinal!=0 && ordinal!=8'he5)begin
        directory_match<=chain_match;directory_cluster<=cluster;
       end
       chain_match<=0;expected<=3;
      end
     end
     default:;
    endcase
   end
  end
 end
endmodule
