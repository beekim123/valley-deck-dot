import { readFile, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const ID = /^[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)*$/;
const validId = v => typeof v === 'string' && ID.test(v);
const NAMES = { wood: '木', stone: '石', warmth: '暖意' };
const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const natural = v => Number.isSafeInteger(v) && v >= 0;
const positive = v => natural(v) && v > 0;
function demand(ok, message) { if (!ok) throw new Error(message); }
function keys(v, allowed, required=allowed) { demand(object(v), 'expected object'); demand(Object.keys(v).every(k=>allowed.includes(k)), `unsupported field: ${Object.keys(v).filter(k=>!allowed.includes(k))}`); demand(required.every(k=>Object.hasOwn(v,k)), `missing field: ${required.filter(k=>!Object.hasOwn(v,k))}`); }
const text = v => typeof v === 'string' && v.trim().length > 0;
function resourceOp(op) {
 keys(op,['op','res','n','bonus_flag','bonus','once_key'],['op','res','n']);
 demand(['gain','spend'].includes(op.op) && Object.hasOwn(NAMES,op.res) && natural(op.n),'invalid resource operation');
 if (op.once_key!==undefined) demand(op.op==='spend' && validId(op.once_key),'invalid once_key');
 if(op.bonus_flag!==undefined || op.bonus!==undefined) demand(op.op==='gain' && validId(op.bonus_flag) && positive(op.bonus) && Number.isSafeInteger(op.n+op.bonus),'invalid conditional resource bonus');
}
export function resourcePreview(ops) {
 demand(Array.isArray(ops),'ops must be array');
 return ops.filter(op=>['gain','spend'].includes(op.op)).map(op=>{
 resourceOp(op); let s=`${op.op==='gain'?'+':'-'}${op.n} ${NAMES[op.res]}`;
 if(op.bonus_flag) s+=`（${op.bonus_flag==='axe_sharp'?'斧头磨好后':op.bonus_flag} +${op.n+op.bonus} ${NAMES[op.res]}）`;
 if(op.once_key) s+='（仅首次）'; return s;
 }).join('，');
}
export function validateLocations(data,{artIds}={}) {
 demand(object(data)&&data.format==='content/1'&&Array.isArray(data.locations)&&data.locations.length,'invalid locations format');
 const ids=new Set(),slots=new Set();
 for(const l of data.locations){
 keys(l,['id','name','start','slot','uses','restore_when','daily','art','pano','reveal_state','reveal_entry_state','thaw_cost','awaken'],['id','name','start','slot','uses','restore_when']);
 demand(validId(l.id)&&l.id.startsWith('loc.'),'invalid location id'); demand(!ids.has(l.id),`duplicate location id ${l.id}`);ids.add(l.id);
 demand(text(l.name)&&['hidden','fog','frozen','thawed','restored'].includes(l.start),'invalid location name/state');
 demand(Array.isArray(l.slot)&&l.slot.length===2&&natural(l.slot[0])&&l.slot[0]<2&&natural(l.slot[1])&&l.slot[1]<6,'slot outside 2x6 board');
 demand(!slots.has(l.slot.join()),'duplicate slot');slots.add(l.slot.join());
 if(l.reveal_state) demand(['frozen','thawed'].includes(l.reveal_state),'invalid reveal state');
 if(l.reveal_entry_state) demand(['fog','frozen','thawed'].includes(l.reveal_entry_state),'invalid reveal entry state');
 if(l.thaw_cost){demand(object(l.thaw_cost),'invalid thaw cost');for(const [r,n] of Object.entries(l.thaw_cost))demand(Object.hasOwn(NAMES,r)&&natural(n),'invalid thaw resource');}
 if(l.daily){keys(l.daily,['res','n']);demand(Object.hasOwn(NAMES,l.daily.res)&&positive(l.daily.n),'invalid daily');}
 demand(Array.isArray(l.uses)&&l.uses.length,'empty uses');const us=new Set();
 for(const u of l.uses){
 keys(u,['id','label','who','requires','ops','preview','progress_key'],['id','label','who','requires','ops','preview']);
 demand(validId(u.id)&&!us.has(u.id),'invalid or duplicate use id');us.add(u.id);
 demand(text(u.label)&&!/[+\-\d]/.test(u.label),'label must be action name');
 demand(u.who==='any'||object(u.who)&&Object.keys(u.who).length===1&&(text(u.who.tag)||text(u.who.resident)),'invalid who selector');
 demand(u.preview===resourcePreview(u.ops),'preview does not match ops');
 }
 if(l.pano){demand(validId(l.pano),'invalid pano id');if(artIds)demand(artIds.has(l.pano),`missing art asset ${l.pano}`);}
 if(l.art)for(const season of ['winter','spring']){demand(validId(l.art[season]||''),`invalid ${season} art id`);if(artIds)demand(artIds.has(l.art[season]),`missing art asset ${l.art[season]}`);}
 }
 return {locations:ids.size};
}
const OP_FIELDS={gain:['op','res','n','bonus_flag','bonus'],spend:['op','res','n','once_key'],reveal:['op','loc'],thaw:['op','loc'],restore:['op','loc'],awaken:['op','resident'],progress:['op','loc','key','n','max'],set_flag:['op','key','value'],grant_spell:['op','id'],story:['op','id'],flood:['op','locations','days'],goal_step:['op','id']};
export function validateContent(defs,{artIds,audioIds}={}) {
 const expected={locations:11,residents:6,combos:17,events:6,visitors:3,spells:2,goals:4};
 const maps={};
 const fixedLocations=['pines','hut','flower_slope','herb_garden','river_bend','misty_bank','tree_hole','mill','gravel','old_bridge','flood_beach'].map(x=>'loc.'+x);
 demand(Array.isArray(defs.locations)&&fixedLocations.every(id=>defs.locations.some(l=>l.id===id)),'immutable location IDs changed');
 for(const k of [...Object.keys(expected),'schedule','pages','banter']){
 demand(Array.isArray(defs[k]),`missing collection ${k}`);if(expected[k])demand(defs[k].length===expected[k],`${k}: expected ${expected[k]}`);
 maps[k]=new Map();for(const x of defs[k]){demand(object(x)&&validId(x.id),`${k}: invalid id`);demand(!maps[k].has(x.id),`duplicate ${k} id`);maps[k].set(x.id,x);}
 }
 const ref=(k,id)=>demand(maps[k].has(id),`missing ${k} reference ${id}`);
 const evref=id=>demand(maps.events.has(id)||maps.visitors.has(id),`missing event ${id}`);
 const locref=id=>ref('locations',id); const resref=id=>ref('residents',id);
 function condition(c){
 demand(object(c),'condition must be object'); const type=Object.keys(c)[0];
 if(['all','any'].includes(type)){keys(c,[type]);demand(Array.isArray(c[type]),'condition list');c[type].forEach(condition);return;}
 if(type==='not'){keys(c,['not']);condition(c.not);return;}
 const fields={flag:['flag','value'],awake:['awake'],location_state:['location_state','value'],progress_at_least:['progress_at_least','loc','n'],goal_done:['goal_done'],combo_done:['combo_done'],event_active:['event_active'],assigned:['assigned','loc'],use_resolved:['use_resolved','loc','resident'],day_at_least:['day_at_least'],days_since:['days_since','target','n']};
 demand(fields[type],`unknown condition ${type}`);keys(c,fields[type]);
 if(type==='flag')demand(validId(c.flag)&&['boolean','string','number'].includes(typeof c.value),'invalid flag');
 if(type==='awake')resref(c.awake);
 if(type==='location_state'){locref(c.location_state);demand(['hidden','fog','frozen','thawed','restored'].includes(c.value),'invalid condition state');}
 if(type==='progress_at_least'){locref(c.loc);demand(validId(c.progress_at_least)&&natural(c.n),'invalid progress condition');demand(Object.hasOwn(defs.balance.progress_caps,c.progress_at_least),'unknown progress key');}
 if(type==='goal_done')ref('goals',c.goal_done);if(type==='combo_done')ref('combos',c.combo_done);if(type==='event_active')evref(c.event_active);
 if(type==='assigned'){resref(c.assigned);locref(c.loc);}
 if(type==='use_resolved'){resref(c.resident);locref(c.loc);demand(maps.locations.get(c.loc).uses.some(u=>u.id===c.use_resolved)||['explore','thaw'].includes(c.use_resolved),'unknown use reference');}
 if(type==='day_at_least')demand(positive(c.day_at_least),'invalid day');
 if(type==='days_since'){demand(['awaken','thaw','reveal'].includes(c.days_since)&&natural(c.n),'invalid days_since');if(c.days_since==='awaken')resref(c.target);else locref(c.target);}
 }
 const owners=new Map(),allOps=[];
 function ops(xs,owner){demand(Array.isArray(xs),'ops must array');for(const op of xs){
 demand(object(op)&&OP_FIELDS[op.op],`unknown operation ${op?.op}`);let required=OP_FIELDS[op.op].filter(k=>!['bonus_flag','bonus','once_key'].includes(k));keys(op,OP_FIELDS[op.op],required);allOps.push(op);
 if(['gain','spend'].includes(op.op))resourceOp(op);
 if(op.once_key){demand(!owners.has(op.once_key)||owners.get(op.once_key)===owner,`once_key has multiple owners ${op.once_key}`);owners.set(op.once_key,owner);}
 if(op.loc)locref(op.loc);if(op.resident)resref(op.resident);
 if(op.op==='progress')demand(validId(op.key)&&positive(op.n)&&positive(op.max)&&op.n<=op.max,'invalid progress');
 if(op.op==='set_flag')demand(validId(op.key)&&['boolean','string','number'].includes(typeof op.value),'invalid flag op');
 if(op.op==='grant_spell')ref('spells',op.id);if(op.op==='story')ref('pages',op.id);if(op.op==='goal_step')ref('goals',op.id);
 if(op.op==='flood'){demand(Array.isArray(op.locations)&&op.locations.length&&positive(op.days)&&op.days<=30,'invalid finite flood');op.locations.forEach(locref);}
 }}
 validateLocations({format:'content/1',locations:defs.locations},{artIds});
 for(const l of defs.locations){condition(l.restore_when);for(const r of l.awaken||[])resref(r);for(const u of l.uses){demand(Array.isArray(u.requires),'requires array');u.requires.forEach(condition);if(u.who.resident)resref(u.who.resident);if(u.who.tag)demand(defs.residents.some(r=>r.tags.includes(u.who.tag)),'unknown tag');ops(u.ops,l.id+'/'+u.id);}}
 demand(defs.residents.filter(r=>r.playable).length===5,'five playable residents required');
 for(const r of defs.residents){keys(r,['id','name','tags','initial_status','home','playable']);demand(text(r.name)&&Array.isArray(r.tags)&&r.tags.every(text)&&['awake','frozen'].includes(r.initial_status)&&typeof r.playable==='boolean','invalid resident');locref(r.home);}
 for(const c of defs.combos){keys(c,['id','loc','who','requires','ops','priority','once','line','use_id','replace_use_gain'],['id','loc','who','requires','ops','priority','once']);locref(c.loc);demand(Array.isArray(c.who)&&[1,2].includes(c.who.length)&&new Set(c.who).size===c.who.length,'invalid combo cast');c.who.forEach(resref);demand(c.once===true&&natural(c.priority)&&Array.isArray(c.requires),'invalid combo');c.requires.forEach(condition);ops(c.ops,c.id);if(c.use_id)demand(maps.locations.get(c.loc).uses.some(u=>u.id===c.use_id),'unknown combo use_id');if(c.replace_use_gain)demand(c.who.length===1&&c.use_id,'replacement must bind one actor/use');}
 for(const e of [...defs.events,...defs.visitors]){keys(e,['id','name','trigger','duration','related_locations','complete_when','done_ops','expire_ops','requirement_text','done_text','expire_text','done_preview','expire_preview','pause_mode'],['id','name','trigger','duration','related_locations','complete_when','done_ops','expire_ops','requirement_text','done_text','expire_text','done_preview','expire_preview']);demand(positive(e.duration)&&e.duration<=30,'invalid finite event duration');for(const f of ['name','requirement_text','done_text','expire_text'])demand(text(e[f]),`missing public event ${f}`);demand(Array.isArray(e.related_locations)&&e.related_locations.length,'event locations required');e.related_locations.forEach(locref);condition(e.trigger);condition(e.complete_when);ops(e.done_ops,e.id+'/done');ops(e.expire_ops,e.id+'/expire');demand(e.done_preview===resourcePreview(e.done_ops)&&e.expire_preview===resourcePreview(e.expire_ops),'event preview mismatch');for(const op of e.done_ops.filter(o=>o.op==='gain'))demand(e.done_text.includes(`+${op.n} ${NAMES[op.res]}`),'event public gain mismatch');if(e.pause_mode)demand(['any','all'].includes(e.pause_mode),'invalid pause_mode');}
 // Exact public resource tokens, including persistent upgrades described by flags.
 const tokens=t=>[...t.matchAll(/([+-]?\d+)\s*(暖意|木|石)/g)].map(m=>`${Number(m[1])}:${m[2]}`).sort();
 for(const e of [...defs.events,...defs.visitors]){
  for(const [which,operations] of [['done',e.done_ops],['expire',e.expire_ops]]){
   const expected=operations.filter(o=>['gain','spend'].includes(o.op)).map(o=>`${o.op==='gain'?o.n:-o.n}:${NAMES[o.res]}`);
   if(e.id==='ev.dull_axe'){
    const chop=maps.locations.get('loc.pines').uses.find(u=>u.id==='chop').ops.find(o=>o.op==='gain');
    expected.push(`${chop.n+(which==='done'?chop.bonus:0)}:${NAMES[chop.res]}`);
   }
   if(e.id==='ev.ice_fireflies'&&which==='done'){const bonus=defs.balance.explorer_bonus;expected.push(`${bonus.n}:${NAMES[bonus.res]}`);}
   demand(JSON.stringify(tokens(e[which+'_text']))===JSON.stringify(expected.sort()),`public resource tokens mismatch ${e.id}/${which}`);
   for(const op of operations.filter(o=>o.op==='flood'))demand(e[which+'_text'].includes(`${op.days} 天`),'public flood duration mismatch');
  }
 }
 for(const s of defs.spells){keys(s,['id','name','effect']);demand(text(s.name)&&['two_actions','extra_flip'].includes(s.effect),'invalid spell');}
 for(const g of defs.goals){keys(g,['id','label','when','hint','related_locations']);condition(g.when);demand(text(g.label)&&text(g.hint),'missing goal text');g.related_locations.forEach(locref);}
 demand(['goal.thaw_mill','goal.wheel','goal.water','goal.family'].every(id=>maps.goals.has(id)),'goal IDs changed');
 for(const s of defs.schedule){keys(s,['id','day','ops']);demand(positive(s.day),'invalid schedule day');ops(s.ops,s.id);}
 for(const s of defs.pages){keys(s,['id','pages']);demand(Array.isArray(s.pages)&&s.pages.length,'empty story');for(const p of s.pages){keys(p,['layers','speaker','text','layout','when'],['layers','speaker','text']);demand(text(p.text)&&[...p.text].length<=50&&text(p.speaker),'invalid story page text');demand(Array.isArray(p.layers),'story layers must array');for(const layer of p.layers){keys(layer,['asset','x','y','frames','fps','pan'],['asset','x','y']);demand(validId(layer.asset),'invalid layer asset');demand(Number.isInteger(layer.x)&&Number.isInteger(layer.y)&&layer.x>=0&&layer.y>=0&&layer.x<=640&&layer.y<=360,'invalid layer coordinates');if(artIds)demand(artIds.has(layer.asset),`missing story asset ${layer.asset}`);if(layer.frames!==undefined)demand(positive(layer.frames),'invalid layer frames');if(layer.fps!==undefined)demand(Number.isFinite(layer.fps)&&layer.fps>0&&layer.fps<=30,'invalid layer fps');if(layer.pan!==undefined)demand(Array.isArray(layer.pan)&&layer.pan.length===2&&layer.pan.every(Number.isInteger),'invalid integer pan');}if(p.layout)demand(['memory','note','illustration'].includes(p.layout),'invalid page layout');if(p.when)condition(p.when);}}
 for(const b of defs.banter){keys(b,['id','event','speaker','when','lines','once','chance','priority','match_id','match_resident','match_location'],['id','event','speaker','when','lines','once','chance','priority']);condition(b.when);demand(Array.isArray(b.lines)&&b.lines.length&&b.lines.every(t=>text(t)&&[...t].length<=18),'invalid banter text');demand(typeof b.once==='boolean'&&b.chance>=0&&b.chance<=1&&natural(b.priority),'invalid banter settings');if(b.match_id)ref('combos',b.match_id);if(b.match_resident)resref(b.match_resident);if(b.match_location&&!['fog','frozen','any'].includes(b.match_location))locref(b.match_location);}
 const b=defs.balance;demand(object(b),'missing balance');keys(b,['content_version','initial_resources','location_capacity','event_capacity','idle_reminder_threshold','thaw_resident','tutorial_residents','flood_reveal_location','flood_end_flag','fallback_story','explorer_bonus','awaken_bonus','progress_caps','test_strategies']);
 keys(b.initial_resources,Object.keys(NAMES));Object.values(b.initial_resources).forEach(n=>demand(natural(n),'invalid initial resource'));for(const k of ['location_capacity','event_capacity','idle_reminder_threshold'])demand(positive(b[k]),'invalid capacity');resref(b.thaw_resident);b.tutorial_residents.forEach(resref);locref(b.flood_reveal_location);ref('pages',b.fallback_story);
 for(const k of ['explorer_bonus','awaken_bonus']){keys(b[k],['resident','flag','res','n']);resref(b[k].resident);demand(validId(b[k].flag)&&Object.hasOwn(NAMES,b[k].res)&&natural(b[k].n),'invalid balance bonus');}
 demand(text(b.content_version)&&validId(b.flood_end_flag),'invalid balance version/flag');
 for(const cap of Object.values(b.progress_caps))demand(positive(cap),'invalid progress cap');
 for(const [key,value] of Object.entries(b.test_strategies))demand(Number.isFinite(value)&&value>=0,`invalid test strategy ${key}`);
 for(const op of allOps.filter(o=>o.op==='progress'))demand(b.progress_caps[op.key]===op.max,'progress max differs from balance');
 // Static closure of presentation/unlock edges only: NOT a dynamic reachability proof.
 const revealed=new Set(defs.locations.filter(l=>l.start!=='hidden').map(l=>l.id));
 for(const op of allOps)if(op.op==='reveal')revealed.add(op.loc);revealed.add(b.flood_reveal_location);
 for(const l of defs.locations)demand(revealed.has(l.id),`hidden location has no reveal edge ${l.id}`);
 const awakeSet=new Set(defs.residents.filter(r=>r.initial_status==='awake').map(r=>r.id));b.tutorial_residents.forEach(id=>awakeSet.add(id));for(const l of defs.locations)for(const id of l.awaken||[])awakeSet.add(id);for(const op of allOps)if(op.op==='awaken')awakeSet.add(op.resident);
 for(const c of defs.combos)demand(revealed.has(c.loc)&&c.who.every(id=>awakeSet.has(id)),`combo missing unlock edges ${c.id}`);
 const recovery={};for(const res of Object.keys(NAMES)){
 const source=defs.locations.find(l=>['thawed','fog'].includes(l.start)&&(l.start!=='fog'||l.reveal_state==='thawed')&&l.uses.some(u=>u.who==='any'&&!u.progress_key&&u.requires.length===0&&!u.ops.some(o=>o.op==='spend')&&u.ops.some(o=>o.op==='gain'&&o.res===res&&o.n>0)));
 demand(source,`no zero-resource recovery source ${res}`);demand(!allOps.some(o=>o.op==='flood'&&o.locations.includes(source.id)),`free recovery source flooded ${res}`);recovery[res]=source.id;
 }
 return {...Object.fromEntries(Object.keys(expected).map(k=>[k,defs[k].length])),recovery,reachability:'static unlock/recovery edges only; dynamic completion requires Godot simulation'};
}
export function validateRegistry(registry) {
  demand(object(registry) && registry.format === 'content/1', 'registry format must be content/1');
  demand(Array.isArray(registry.files) && registry.files.length > 0, 'registry files must be nonempty');
  const ids = new Set(), paths = new Set();
  for (const file of registry.files) {
    demand(object(file) && typeof file.id === 'string' && validId(file.id), 'invalid registry id');
    demand(!ids.has(file.id), `duplicate registry id: ${file.id}`); ids.add(file.id);
    demand(typeof file.path === 'string' && /^(data|story)\/[a-z0-9_./-]+\.json$/.test(file.path)
      && file.path.split('/').every(part => part !== '.' && part !== '..' && part.length > 0), 'unsafe registry path');
    demand(!paths.has(file.path), `duplicate registry path: ${file.path}`); paths.add(file.path);
  }
  return registry.files;
}

async function json(file) { return JSON.parse(await readFile(file, 'utf8')); }
async function manifestIds(file, required, warnings) {
  let manifest;
  try { manifest = await json(file); }
  catch (error) {
    if (error.code !== 'ENOENT' || required) throw error;
    warnings.push(`Asset check skipped: ${path.basename(path.dirname(path.dirname(file)))}/export/${path.basename(file)} missing`);
    return undefined;
  }
  demand(object(manifest) && Array.isArray(manifest.assets), `invalid asset manifest: ${file}`);
  const ids = new Set();
  for (const asset of manifest.assets) {
    demand(object(asset) && typeof asset.id === 'string' && validId(asset.id) && !ids.has(asset.id), 'invalid or duplicate asset id');
    ids.add(asset.id);
  }
  return ids;
}

export async function checkContent({root=ROOT,requireAssets=false}={}) {
 const content=path.resolve(root,'content');const files=validateRegistry(await json(path.join(content,'registry.json')));const warnings=[];
 const artIds=await manifestIds(path.join(root,'resources/art/export/manifest.json'),requireAssets,warnings);
 const audioIds=await manifestIds(path.join(root,'resources/audio/export/manifest.json'),requireAssets,warnings);
 const defs={};for(const f of files){const resolved=await realpath(path.join(content,f.path));demand(resolved.startsWith(await realpath(content)+path.sep),'registry symlink escapes content root');const value=await json(resolved);keys(value,['format',f.id]);demand(value.format==='content/1','invalid content format');defs[f.id]=value[f.id];}
 demand(files.length===11,'expected complete eleven-collection registry');
 return {files:files.length,...validateContent(defs,{artIds,audioIds}),warnings};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{demand(process.argv.slice(2).every(x=>x==='--require-assets'),'usage: content-check.mjs [--require-assets]');const result=await checkContent({requireAssets:process.argv.includes('--require-assets')});console.log(JSON.stringify(result,null,2));}
 catch(e){console.error(`Content check failed: ${e.message}`);process.exitCode=1;}
}
