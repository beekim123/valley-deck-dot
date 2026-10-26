import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { PixelCanvas, palette, characterFrame } from '../../resources/art/lib/pixel.mjs';
import { encodePNG, decodePNG } from '../../resources/art/lib/png.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url)),art=path.join(root,'resources/art'),output=path.join(art,'export');
const sha=data=>createHash('sha256').update(data).digest('hex');
async function files(dir){let list=[];try{for(const entry of await readdir(dir,{withFileTypes:true})){const name=path.join(dir,entry.name);list.push(...entry.isDirectory()?await files(name):[name]);}}catch(e){if(e.code!=='ENOENT')throw e;}return list.sort();}
export function validateMeta(m){
 if(!/^[a-z][a-z0-9_.]*$/.test(m.id))throw new Error('Invalid art id');
 if(!Array.isArray(m.size)||m.size.length!==2||!m.size.every(n=>Number.isInteger(n)&&n>0))throw new Error(`${m.id}: invalid size`);
 if(!Number.isInteger(m.frames)||m.frames<1)throw new Error(`${m.id}: invalid frames`);
 if(!Array.isArray(m.anchor)||m.anchor.length!==2||!m.anchor.every((n,i)=>Number.isInteger(n)&&n>=0&&n<=m.size[i]))throw new Error(`${m.id}: invalid anchor`);
 if(!m.animations||!Object.keys(m.animations).length)throw new Error(`${m.id}: animations required`);
 for(const a of Object.values(m.animations))if(!Number.isFinite(a.fps)||a.fps<=0||typeof a.loop!=='boolean'||!Array.isArray(a.frames)||!a.frames.length||!a.frames.every(n=>Number.isInteger(n)&&n>=0&&n<m.frames))throw new Error(`${m.id}: invalid animation`);
 if(m.nineSlice&&(!Array.isArray(m.nineSlice)||m.nineSlice.length!==4||!m.nineSlice.every(n=>Number.isInteger(n)&&n>=0)||m.nineSlice[0]+m.nineSlice[2]>m.size[0]||m.nineSlice[1]+m.nineSlice[3]>m.size[1]))throw new Error(`${m.id}: invalid nineSlice`);
}
export function validatePixels(g){const allowed=new Set(Object.values(palette.colors).map(c=>c.slice(1).toLowerCase()));for(let i=0;i<g.pixels.length;i+=4){const a=g.pixels[i+3];if(a!==0&&a!==255)throw new Error('Partial alpha');if(a===255&&!allowed.has(Buffer.from(g.pixels.subarray(i,i+3)).toString('hex')))throw new Error('Off-palette color');}}
export async function renderAssets(){
 if(Object.keys(palette.colors).length!==48||new Set(Object.values(palette.colors)).size!==48)throw new Error('Palette must have 48 unique colors');
 const assets=[];
 for(const file of await files(path.join(art,'source'))){
  if(file.endsWith('.json')){const source=JSON.parse(await readFile(file,'utf8'));if(source.format!=='art/1')throw new Error(`Unknown format: ${file}`);const frames=source.frames.map(rows=>characterFrame(rows,source.size));for(const v of source.variants??[]){if(!frames[v.sourceFrame]||!palette.recolors[v.recolor])throw new Error('Invalid frame variant');frames.push(frames[v.sourceFrame].clone().recolor(palette.recolors[v.recolor]));}const {variants,format,frames:ignored,...meta}=source;assets.push({meta:{...meta,frames:frames.length},frames});}
  else if(file.endsWith('.mjs')){const mod=await import(pathToFileURL(file));for(const a of mod.assets){const frames=[];for(let frame=0;frame<a.meta.frames;frame++){const g=new PixelCanvas(...a.meta.size);a.draw(g,{frame,seed:7261});frames.push(g);}assets.push({meta:a.meta,frames});}}
 }
 assets.sort((a,b)=>a.meta.id.localeCompare(b.meta.id,'en'));
 const ids=new Set();for(const a of assets){validateMeta(a.meta);if(ids.has(a.meta.id))throw new Error('Duplicate art id');ids.add(a.meta.id);const strip=new PixelCanvas(a.meta.size[0]*a.frames.length,a.meta.size[1]);a.frames.forEach((g,i)=>{validatePixels(g);strip.stamp(g,i*g.width,0);});a.png=encodePNG(strip.width,strip.height,strip.pixels);a.entry={...a.meta,file:`${a.meta.id}.png`,hash:sha(a.png)};}
 return assets;
}
async function references(assets){
 const ids=new Set(assets.map(a=>a.meta.id)),used=new Set();
 // Recognize semantic art IDs in any content field, including nested layers and arrays.
 for(const file of await files(path.join(root,'content')))if(file.endsWith('.json')){
  const walk=value=>{if(typeof value==='string'&&/^(portrait|locart|pano|card|board|deco|big|walker|char|icon|fx|still|note\.(paper|sketch)|ui)\./.test(value)){if(!ids.has(value))throw new Error(`Missing art reference ${value} in ${path.relative(root,file)}`);used.add(value);}else if(Array.isArray(value))value.forEach(walk);else if(value&&typeof value==='object')Object.values(value).forEach(walk);};walk(JSON.parse(await readFile(file,'utf8')));
 }
 for(const id of ids)if(!used.has(id))console.warn(`art warning: ${id} is not referenced by content (may be used by title/QA)`);
}
// Small first-party 3×5 annotation alphabet; never used for in-game text.
const font={A:'010101111101101',B:'110101110101110',C:'011100100100011',D:'110101101101110',E:'111100110100111',F:'111100110100100',G:'011100101101011',H:'101101111101101',I:'111010010010111',J:'001001001101010',K:'101101110101101',L:'100100100100111',M:'101111111101101',N:'101111111111101',O:'010101101101010',P:'110101110100100',Q:'010101101111011',R:'110101110101101',S:'011100010001110',T:'111010010010010',U:'101101101101111',V:'101101101101010',W:'101101111111101',X:'101101010101101',Y:'101101010010010',Z:'111001010100111','0':'111101101101111','1':'010110010010111','2':'110001010100111','3':'110001010001110','4':'101101111001001','5':'111100110001110','6':'011100111101111','7':'111001010010010','8':'111101111101111','9':'111101111001110','.':'000000000000010','-':'000000111000000',' ':'000000000000000'};
function text(g,s,x,y){for(const c of s.toUpperCase()){const bits=font[c]??font[' '];for(let yy=0;yy<5;yy++)for(let xx=0;xx<3;xx++)if(bits[yy*3+xx]==='1')g.px(x+xx,y+yy,'snow2');x+=4;}}
export async function run(command){
 const assets=await renderAssets(),manifest=JSON.stringify({format:'art-manifest/1',assets:assets.map(a=>a.entry)},null,2)+'\n';
 if(command==='build'){await mkdir(output,{recursive:true});for(const a of assets)await writeFile(path.join(output,a.entry.file),a.png);await writeFile(path.join(output,'manifest.json'),manifest);console.log(`art: built ${assets.length} assets`);}
 else if(command==='verify'){
  if(await readFile(path.join(output,'manifest.json'),'utf8')!==manifest)throw new Error('Art manifest differs from source');
  for(const a of assets){const actual=await readFile(path.join(output,a.entry.file));if(!actual.equals(a.png))throw new Error(`${a.meta.id}: stale PNG`);const decoded=decodePNG(actual);if(decoded.width!==a.meta.size[0]*a.meta.frames||decoded.height!==a.meta.size[1])throw new Error('PNG dimensions differ');validatePixels(decoded);}
  const again=await renderAssets();for(let i=0;i<assets.length;i++)if(!assets[i].png.equals(again[i].png))throw new Error('Nondeterministic draw');await references(assets);console.log(`art: verified ${assets.length} PNGs, palette, alpha, metadata, determinism and content references`);
 }else if(command==='sheet'){
  const width=320,height=assets.reduce((h,a)=>h+Math.max(...a.meta.size.slice(1))+19,14);const g=new PixelCanvas(width,height).fill('ink');text(g,'VALLEY DECK - D0 ART',8,5);let y=20;
  for(const a of assets){text(g,a.meta.id,8,y);y+=8;a.frames.forEach((f,i)=>g.stamp(f,8+i*(f.width+7),y));y+=a.meta.size[1]+11;}
  const enlarged=new PixelCanvas(width*3,height*3).stamp(g,0,0,3);await mkdir(path.join(output,'sheets'),{recursive:true});await writeFile(path.join(output,'sheets/d0.png'),encodePNG(enlarged.width,enlarged.height,enlarged.pixels));console.log('art: sheet resources/art/export/sheets/d0.png (3x nearest neighbor)');
 }else throw new Error('Usage: node tools/resources/art.mjs build|verify|sheet');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))run(process.argv[2]).catch(e=>{console.error(e.message);process.exitCode=1;});
