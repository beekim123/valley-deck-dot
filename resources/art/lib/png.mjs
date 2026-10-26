// First-party deterministic RGBA PNG codec. No external image inputs or packages.
import { deflateSync, inflateSync } from 'node:zlib';
const signature = Buffer.from([137,80,78,71,13,10,26,10]);
export function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) { crc ^= byte; for (let k=0;k<8;k++) crc=(crc>>>1)^((crc&1)?0xedb88320:0); }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const name=Buffer.from(type), out=Buffer.alloc(data.length+12);
  out.writeUInt32BE(data.length); name.copy(out,4); data.copy(out,8);
  out.writeUInt32BE(crc32(Buffer.concat([name,data])),data.length+8); return out;
}
export function encodePNG(width, height, pixels) {
  if (!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||width>16384||height>16384||pixels.length!==width*height*4) throw new Error('Invalid PNG dimensions/data');
  const header=Buffer.alloc(13); header.writeUInt32BE(width); header.writeUInt32BE(height,4); header[8]=8; header[9]=6;
  const raw=Buffer.alloc(height*(width*4+1));
  for(let y=0;y<height;y++) Buffer.from(pixels.subarray(y*width*4,(y+1)*width*4)).copy(raw,y*(width*4+1)+1);
  return Buffer.concat([signature,chunk('IHDR',header),chunk('IDAT',deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);
}
export function decodePNG(bytes) {
  const data=Buffer.from(bytes); if(!data.subarray(0,8).equals(signature)) throw new Error('Invalid PNG signature');
  let pos=8,width,height,ended=false; const parts=[];
  while(pos<data.length) {
    if(pos+12>data.length) throw new Error('Truncated PNG chunk');
    const n=data.readUInt32BE(pos),type=data.toString('ascii',pos+4,pos+8),end=pos+8+n;
    if(end+4>data.length) throw new Error('Truncated PNG data');
    if(crc32(data.subarray(pos+4,end))!==data.readUInt32BE(end)) throw new Error('PNG CRC mismatch');
    const body=data.subarray(pos+8,end);
    if(type==='IHDR') { if(width||n!==13||body[8]!==8||body[9]!==6||body[10]||body[11]||body[12]) throw new Error('Only noninterlaced RGBA8 PNG supported'); width=body.readUInt32BE(0);height=body.readUInt32BE(4); if(!width||!height||width*height>16777216)throw new Error('PNG dimensions out of bounds'); }
    else if(type==='IDAT') parts.push(body);
    else if(type==='IEND') {ended=true;pos=end+4;break;}
    pos=end+4;
  }
  if(!width||!ended||pos!==data.length)throw new Error('Incomplete PNG');
  const stride=width*4,raw=inflateSync(Buffer.concat(parts),{maxOutputLength:height*(stride+1)}),pixels=new Uint8Array(width*height*4);
  if(raw.length!==height*(stride+1))throw new Error('PNG scanline size mismatch');
  const paeth=(a,b,c)=>{const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);return pa<=pb&&pa<=pc?a:pb<=pc?b:c;};
  for(let y=0;y<height;y++) {
    const filter=raw[y*(stride+1)]; if(filter>4)throw new Error('Invalid PNG filter');
    for(let x=0;x<stride;x++) {const i=y*stride+x,a=x>=4?pixels[i-4]:0,b=y?pixels[i-stride]:0,c=y&&x>=4?pixels[i-stride-4]:0;
      pixels[i]=(raw[y*(stride+1)+x+1]+[0,a,b,Math.floor((a+b)/2),paeth(a,b,c)][filter])&255;}
  }
  return {width,height,pixels};
}
