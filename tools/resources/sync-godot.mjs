import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {root} from '../lib/paths.mjs';
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const safe = p => {
 if(typeof p !== 'string' || !p || path.isAbsolute(p) || /^[A-Za-z]:/.test(p) || p.includes('\\') || p.split('/').some(c=>!c || c==='.' || c==='..')) throw Error('Unsafe managed path: '+p);
 return p;
};
// Check every existing component, including dangling symlinks. Missing destination
// components are permitted, but their nearest existing ancestor must be contained.
function checked(base, relative) {
 safe(relative);
 const anchor=fs.realpathSync(base);
 let current=anchor;
 for(const component of relative.split('/')) {
  current=path.join(current,component);
  let stat;
  try {stat=fs.lstatSync(current);} catch(error) {if(error.code==='ENOENT')continue;throw error;}
  if(stat.isSymbolicLink())throw Error('Symlink in managed path: '+relative);
  const resolved=fs.realpathSync(current), rel=path.relative(anchor,resolved);
  if(rel==='..'||rel.startsWith('..'+path.sep)||path.isAbsolute(rel))throw Error('Managed path escapes root: '+relative);
 }
 return current;
}
export function inventory(base=root) {
 const read=p=>JSON.parse(fs.readFileSync(checked(base,p),'utf8'));
 const result=[];
 const add=(id,source,dest)=>{safe(dest);const bytes=fs.readFileSync(checked(base,source));result.push({id,source,path:dest,sha256:hash(bytes)});};
 for(const kind of ['art','audio']) {
  const prefix=`resources/${kind}/export`;
  const manifest=read(`${prefix}/manifest.json`);
  add(`manifest.${kind}`,`${prefix}/manifest.json`,`resources/${kind}/manifest.json`);
  for(const a of manifest.assets) add(a.id,`${prefix}/${safe(a.file)}`,`resources/${kind}/${a.file}`);
 }
 const registry=read('content/registry.json');
 add('registry.content','content/registry.json','data/registry.json');
 for(const f of registry.files) add(`content.${f.id}`,`content/${safe(f.path)}`,`data/${f.path}`);
 const walk=d=>fs.readdirSync(checked(base,d),{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name)).flatMap(e=>{
  const p=`${d}/${e.name}`;checked(base,p);
  return e.isDirectory()?walk(p):[p];
 });
 for(const f of walk('third_party/fonts')) add(`font.${f.slice(18)}`,f,`resources/fonts/${f.slice(18)}`);
 const paths=new Set();for(const f of result){if(paths.has(f.path))throw Error('Duplicate managed path '+f.path);paths.add(f.path);}
 return result.sort((a,b)=>a.path.localeCompare(b.path));
}
export function sync(verify=false,base=root) {
 const files=inventory(base),pack={format:'resource-pack/1',files};
 const packPath=checked(base,'godot/resource-pack.json');
 const prev=fs.existsSync(packPath)?JSON.parse(fs.readFileSync(packPath,'utf8')):{files:[]};
 // Preflight all writes AND obsolete deletions before changing anything.
 const target=p=>{safe(p);if(!/^(resources|data)\//.test(p))throw Error('Invalid prior managed path: '+p);return checked(base,`godot/${p}`);};
 for(const f of [...files,...(prev.files??[])]) {
  const p=target(f.path);
  if(fs.existsSync(p)&&!fs.statSync(p).isFile())throw Error('Managed destination is not a file: '+f.path);
 }
 if(verify) {
  if(JSON.stringify(prev)!==JSON.stringify(pack))throw Error('Resource pack is stale; run npm run sync');
  for(const f of files)if(!fs.existsSync(target(f.path))||hash(fs.readFileSync(target(f.path)))!==f.sha256)throw Error('Copy mismatch '+f.path);
 }else{
  for(const f of files){const to=target(f.path);fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(checked(base,f.source),target(f.path));}
  const active=new Set(files.map(f=>f.path));for(const f of prev.files??[])if(!active.has(f.path))fs.rmSync(target(f.path),{force:true});
  fs.writeFileSync(checked(base,'godot/resource-pack.json'),JSON.stringify(pack,null,2)+'\n');
 }
 console.log(`${verify?'Verified':'Synchronized'} ${files.length} managed files`); return files;
}
if(process.argv[1]===fileURLToPath(import.meta.url))sync(process.argv.includes('--verify'));
