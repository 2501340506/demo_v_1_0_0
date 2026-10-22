// Preview of the v0.26 waveform on a publicity BMP (same model as tb_wave_pixels).
// usage: node preview.js <in.bmp> <out.bmp>
const fs=require('fs');const [src,dst]=process.argv.slice(2);
const b=fs.readFileSync(src);const off=b.readUInt32LE(10),w=b.readInt32LE(18),h=b.readInt32LE(22);
const stride=Math.ceil(w*3/4)*4;
// Speech-like history: newest at index 0..39.
const hist=[];for(let i=0;i<40;i++)hist.push(Math.min(28,Math.round(14+12*Math.sin(i*0.9)*Math.sin(i*0.23+1))));
const wash=(c,bl,k)=>c-((c*k)>>4)+((bl*k)>>4);
for(let py=448;py<480;py++)for(let px=0;px<640;px++){
 const row=h>0?h-1-py:py,p=off+row*stride+px*3;
 const slot=px>>3,idx=slot<40?39-slot:slot-40,e=idx;
 const wgt=Math.round(2+14*Math.cos(Math.PI*e/80)**2);
 const hv=Math.max(0,hist[idx]),half=((hv*wgt)>>5)+1;
 const r=py<464?463-py:py-464,col=px%8,k=4+((py-448)>>2)+((py-448)>>3);
 const ink=r<half&&(r==half-1?col>=3&&col<5:col>=2&&col<6);
 if(ink){b[p]=b[p+1]=b[p+2]=255;}else{b[p]=wash(b[p],0xf0,k);b[p+1]=wash(b[p+1],0x82,k);b[p+2]=wash(b[p+2],0x3c,k);}
}
fs.writeFileSync(dst,b);
