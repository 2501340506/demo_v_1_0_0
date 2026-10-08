function [7:0] fat32_metadata(input integer lba,input integer off,input integer file_bytes,input integer images);
 integer v,n,id,part,sectors;
 begin
 fat32_metadata=0;v=0;sectors=(file_bytes+511)/512;
 if(lba==0)begin
 case(off)
 11:fat32_metadata=0;12:fat32_metadata=2;13:fat32_metadata=1;14:fat32_metadata=1;16:fat32_metadata=1;
 32,33,34,35:fat32_metadata=32'd66561>>(8*(off-32));
 36,37,38,39:fat32_metadata=32'd1024>>(8*(off-36));
 44:fat32_metadata=2;510:fat32_metadata=8'h55;511:fat32_metadata=8'haa;
 default:fat32_metadata=0;endcase
 end else if(lba<1025)begin
 n=(lba-1)*128+off/4;
 if(n<=2)v=32'h0fffffff;
 else if(n<3+images*sectors)begin
 if((n-3)%sectors==sectors-1)v=32'h0fffffff;else v=n+1;
 end
 fat32_metadata=v>>(8*(off%4));
 end else if(lba==1025)begin
 id=off/32;part=off%32;
 if(id<images)case(part)
 0:fat32_metadata="P";1:fat32_metadata="I";2:fat32_metadata="C";3:fat32_metadata="1"+id;
 4,5,6,7:fat32_metadata=" ";8:fat32_metadata="B";9:fat32_metadata="M";10:fat32_metadata="P";11:fat32_metadata=8'h20;
 20:fat32_metadata=(3+id*sectors)>>16;21:fat32_metadata=(3+id*sectors)>>24;
 26:fat32_metadata=3+id*sectors;27:fat32_metadata=(3+id*sectors)>>8;
 28,29,30,31:fat32_metadata=file_bytes>>(8*(part-28));default:fat32_metadata=0;endcase
 end
 end
endfunction
