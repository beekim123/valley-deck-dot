import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile,mkdtemp,mkdir,writeFile,symlink,rm,cp } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { checkContent,resourcePreview,validateLocations,validateRegistry,validateContent } from '../tools/qa/content-check.mjs';
const root=path.resolve(import.meta.dirname,'..');
const registry=JSON.parse(await readFile(path.join(root,'content/registry.json')));
const defs={};for(const f of registry.files)defs[f.id]=JSON.parse(await readFile(path.join(root,'content',f.path)))[f.id];
const artIds=new Set(JSON.parse(await readFile(path.join(root,'resources/art/export/manifest.json'))).assets.map(a=>a.id));
function modified(edit){const x=structuredClone(defs);edit(x);return x;}
function reject(edit,re){assert.throws(()=>validateContent(modified(edit),{artIds}),re);}
test('D1 complete immutable collections and free recovery edges',()=>{
 const result=validateContent(defs,{artIds});assert.equal(result.locations,11);assert.equal(result.combos,17);assert.equal(result.residents,6);
 assert.deepEqual(result.recovery,{wood:'loc.pines',stone:'loc.gravel',warmth:'loc.flower_slope'});
 assert.match(result.reachability,/static/);assert.equal(defs.residents.filter(r=>r.playable).length,5);
 assert.deepEqual(defs.locations[0].slot,[0,0]);assert.deepEqual(defs.locations[0].uses.map(u=>u.id),['chop','gather']);
});
test('preview template preserves costs, bonuses, and first-use material payment',()=>{
 assert.equal(resourcePreview([{op:'spend',res:'wood',n:1},{op:'gain',res:'warmth',n:1}]),'-1 木，+1 暖意');
 assert.equal(resourcePreview(defs.locations[0].uses[0].ops),'+2 木（斧头磨好后 +3 木）');
 assert.match(defs.locations.find(l=>l.id==='loc.mill').uses[0].preview,/仅首次/);
 reject(d=>d.locations[0].uses[0].preview='+99 木',/preview/);
 reject(d=>d.locations[0].uses[0].label='伐木 +99 木',/label/);
});
test('invalid resources, unsafe integers, malformed fields and unknown ops fail closed',()=>{
 for(const op of [{op:'gain',res:'food',n:1},{op:'gain',res:'wood',n:-1},{op:'gain',res:'wood',n:0.5},{op:'gain',res:'wood',n:Number.MAX_SAFE_INTEGER+1},{op:'gain',res:'wood',n:1,bonus:1},{op:'gain',res:'wood',n:1,unexpected:true}])assert.throws(()=>resourcePreview([op]));
 assert.equal(resourcePreview([{op:'gain',res:'wood',n:0}]),'+0 木');
 reject(d=>d.combos[0].ops.push({op:'execute',code:'bad'}),/unknown operation/);
 reject(d=>d.combos[0].ops.push({op:'restore',loc:'loc.pines',extra:true}),/unsupported field/);
 reject(d=>d.combos[0].ops.push({op:'progress',loc:'loc.mill',key:'wheel',n:-1,max:2}),/invalid progress/);
});
test('exact AST keys, target ids, use references and positive dates are checked',()=>{
 for(const cond of [{resource_greater:'wood',n:2},{awake:'res.missing'},{location_state:'loc.missing',value:'thawed'},{flag:'a',value:true,extra:2},{use_resolved:'missing',loc:'loc.pines',resident:'res.toby'},{days_since:'sleep',target:'res.toby',n:1},{day_at_least:0},{progress_at_least:'wheel',loc:'loc.mill',n:-1}])reject(d=>d.combos[0].requires=[cond]);
 reject(d=>d.combos[0].use_id='typo',/use_id/);
 reject(d=>d.residents[0].home='loc.missing',/reference/);
 reject(d=>d.combos[0].ops[0].id='story.missing',/reference/);
 reject(d=>d.locations[0].uses[0].who={tag:'unknown'},/unknown tag/);
});
test('duplicate ids/slots, wrong states/selectors, unsupported collections and count loss fail',()=>{
 reject(d=>d.locations[1].id=d.locations[0].id,/immutable|duplicate/);
 reject(d=>d.locations[1].slot=[0,0],/duplicate slot/);
 reject(d=>d.locations.pop(),/immutable|expected 11/);
 for(const edit of [d=>d.locations[0].slot=[2,0],d=>d.locations[0].start='defeated',d=>d.locations[0].uses[0].who='res.toby',d=>d.locations[0].uses.push(structuredClone(d.locations[0].uses[0])),d=>d.locations[0].restore={combo:'combo.missing'}])reject(edit);
});
test('once_key can cover both materials only for a single action owner',()=>{
 const repair=defs.locations.find(l=>l.id==='loc.mill').uses[0];assert.equal(repair.ops[0].once_key,repair.ops[1].once_key);
 reject(d=>{d.locations[1].uses[0].ops[0].once_key='mill.wheel_materials';d.locations[1].uses[0].preview=resourcePreview(d.locations[1].uses[0].ops);},/multiple owners/);
});
test('recovery source must be unconditional, renewable, free and not floodable',()=>{
 reject(d=>{const l=d.locations.find(l=>l.id==='loc.gravel');l.uses[0].requires=[{flag:'trap',value:true}];},/no zero-resource recovery source stone/);
 reject(d=>{const u=d.locations[0].uses[1];u.ops.unshift({op:'spend',res:'warmth',n:1});u.preview=resourcePreview(u.ops);},/recovery source.*wood/);
 reject(d=>{d.events.find(e=>e.id==='ev.storm').expire_ops[0].locations.push('loc.flower_slope');},/free recovery source flooded/);
 reject(d=>{d.events.find(e=>e.id==='ev.storm').expire_ops[0].days=0;},/finite flood/);
 reject(d=>{d.schedule=[];},/hidden location has no reveal edge/);
});
test('event counts, public gain text, finite timers and exact previews cannot drift',()=>{
 reject(d=>d.events[0].duration=Infinity,/finite event duration/);
 reject(d=>d.events.find(e=>e.id==='ev.peddler').done_text='+99 暖意',/public gain mismatch/);
 reject(d=>d.events[0].done_preview='+99 木',/event preview/);
 reject(d=>d.events[0].done_text='伐木 +99 木',/public resource tokens/);
 reject(d=>d.events.find(e=>e.id==='ev.ice_fireflies').done_text='米拉探路 +2 木',/public resource tokens/);
 reject(d=>d.events.find(e=>e.id==='ev.storm').expire_text='河湾和旧桥淹 9 天',/public flood/);
 reject(d=>d.visitors[0].expire_text='',/public event/);
 reject(d=>d.spells[0].effect='teleport',/spell/);
});
test('only real art references and validated D2 layers are accepted',()=>{
 assert.throws(()=>validateLocations({format:'content/1',locations:defs.locations},{artIds:new Set()}),/missing art asset/);
 reject(d=>d.locations[0].art.spring='',/invalid spring/);
 reject(d=>d.pages[0].pages[0].layers=[{art:'missing'}],/unsupported field|missing field/);
 reject(d=>d.pages[0].pages[0].text='字'.repeat(51),/page text/);
 reject(d=>d.pages[0].pages[0].layers=[{asset:'still.missing',x:0,y:0}],/missing story asset/);
 reject(d=>d.pages[0].pages[0].layers=[{asset:'still.hut',x:0.5,y:0}],/coordinates/);
 reject(d=>d.pages[0].pages[0].layers=[{asset:'still.hut',x:0,y:0,pan:[0.2,0]}],/integer pan/);
 reject(d=>d.banter[0].lines=['字'.repeat(19)],/banter text/);
});
test('registry rejects unsafe paths and duplicate ids/files',()=>{
 assert.deepEqual(validateRegistry(registry),registry.files);
 for(const p of ['../secret.json','/tmp/a.json','data/../../a.json','data/./a.json','data//a.json','data\\a.json','https://example.com/a.json'])assert.throws(()=>validateRegistry({format:'content/1',files:[{id:'locations',path:p}]}),/unsafe/);
 assert.throws(()=>validateRegistry({...registry,files:[...registry.files,registry.files[0]]}),/duplicate/);
 assert.throws(()=>validateRegistry({...registry,files:[...registry.files,{id:'other',path:registry.files[0].path}]}),/duplicate registry path/);
});
test('integration optional assets warn; mandatory assets and symlink confinement are enforced',async t=>{
 const temp=await mkdtemp(path.join(os.tmpdir(),'valley-content-'));t.after(()=>rm(temp,{recursive:true,force:true}));
 await cp(path.join(root,'content'),path.join(temp,'content'),{recursive:true});
 const result=await checkContent({root:temp});assert.equal(result.files,11);assert.equal(result.warnings.length,2);
 await assert.rejects(checkContent({root:temp,requireAssets:true}),/ENOENT/);
 for(const kind of ['art','audio']){const dir=path.join(temp,`resources/${kind}/export`);await mkdir(dir,{recursive:true});await writeFile(path.join(dir,'manifest.json'),JSON.stringify({assets:kind==='art'?[...artIds].map(id=>({id})):[]}));}
 assert.equal((await checkContent({root:temp,requireAssets:true})).warnings.length,0);
 const lp=path.join(temp,'content/data/locations.json');await rm(lp);const outside=path.join(temp,'outside.json');await writeFile(outside,JSON.stringify({format:'content/1',locations:defs.locations}));await symlink(outside,lp);
 await assert.rejects(checkContent({root:temp}),/symlink escapes/);
});
