import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {sync} from '../tools/resources/sync-godot.mjs';
const put=(base,p,data)=>{const f=path.join(base,p);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,typeof data==='string'?data:JSON.stringify(data));};
function fixture(t) {
 const base=fs.mkdtempSync(path.join(os.tmpdir(),'valley-sync-'));
 t.after(()=>fs.rmSync(base,{recursive:true,force:true}));
 for(const kind of ['art','audio']) {
  put(base,`resources/${kind}/export/manifest.json`,{assets:[{id:`${kind}.sample`,file:'sample.bin'}]});
  put(base,`resources/${kind}/export/sample.bin`,kind);
 }
 put(base,'content/registry.json',{files:[{id:'places',path:'data/places.json'}]});
 put(base,'content/data/places.json',{places:[]});
 put(base,'third_party/fonts/LICENSE','license');
 return base;
}
test('sync is deterministic, verifies bytes read-only, deletes only prior managed files',t=>{
 const base=fixture(t);sync(false,base);sync(true,base);
 const pack=fs.readFileSync(path.join(base,'godot/resource-pack.json'));
 sync(false,base);assert.deepEqual(fs.readFileSync(path.join(base,'godot/resource-pack.json')),pack);
 put(base,'godot/resources/local.txt','keep');
 put(base,'resources/art/export/manifest.json',{assets:[]});
 sync(false,base);assert.equal(fs.existsSync(path.join(base,'godot/resources/art/sample.bin')),false);
 assert.equal(fs.readFileSync(path.join(base,'godot/resources/local.txt'),'utf8'),'keep');
 put(base,'godot/resources/audio/sample.bin','tampered');
 assert.throws(()=>sync(true,base),/Copy mismatch/);
 assert.equal(fs.readFileSync(path.join(base,'godot/resources/audio/sample.bin'),'utf8'),'tampered');
});
test('unsafe relative paths and duplicate targets fail closed',t=>{
 const base=fixture(t);
 for(const file of ['../escape','/tmp/escape','x/../../escape','C:\\escape','x\\escape','./sample.bin']) {
  put(base,'resources/art/export/manifest.json',{assets:[{id:'bad',file}]});
  assert.throws(()=>sync(false,base),/Unsafe/);
 }
 put(base,'resources/art/export/manifest.json',{assets:[{id:'one',file:'sample.bin'},{id:'two',file:'sample.bin'}]});
 assert.throws(()=>sync(false,base),/Duplicate/);
});
for(const p of ['resources/art/export/sample.bin','resources/art/export/manifest.json','content/data','third_party/fonts','godot','godot/resources','godot/resource-pack.json','godot/resources/art/sample.bin']) {
 test(`rejects symlink at ${p}`,t=>{
  const base=fixture(t);sync(false,base);
  const original=path.join(base,p), moved=path.join(base,'outside');
  fs.renameSync(original,moved);fs.symlinkSync(moved,original);
  assert.throws(()=>sync(false,base),/Symlink/);
  assert.throws(()=>sync(true,base),/Symlink/);
 });
}
test('obsolete deletion cannot follow a symlink or traversal, even before other writes',t=>{
 const base=fixture(t);sync(false,base);
 put(base,'outside/victim','preserve');
 fs.symlinkSync(path.join(base,'outside'),path.join(base,'godot/resources/obsolete'));
 const original=JSON.parse(fs.readFileSync(path.join(base,'godot/resource-pack.json')));
 for(const p of ['resources/obsolete/victim','../outside/victim','scripts/keep.gd']) {
  put(base,'godot/resource-pack.json',{...original,files:[...original.files,{path:p}]});
  assert.throws(()=>sync(false,base),/Symlink|Unsafe|Invalid prior/);
  assert.equal(fs.readFileSync(path.join(base,'outside/victim'),'utf8'),'preserve');
 }
});
test('dangling destination symlink is rejected',t=>{
 const base=fixture(t);sync(false,base);
 fs.unlinkSync(path.join(base,'godot/resources/art/sample.bin'));
 fs.symlinkSync(path.join(base,'missing'),path.join(base,'godot/resources/art/sample.bin'));
 assert.throws(()=>sync(false,base),/Symlink/);
});
function cliFixture(t) {
 const base=fixture(t);
 for(const p of ['tools/godot/cli.mjs','tools/lib/paths.mjs'])put(base,p,fs.readFileSync(new URL('../'+p,import.meta.url),'utf8'));
 const fake=path.join(base,'fake-godot');
 put(base,'fake-godot',`#!/usr/bin/env node
const fs=require('fs');
const a=process.argv.slice(2);
fs.appendFileSync(process.env.CALL_LOG,JSON.stringify({args:a,config:process.env.XDG_CONFIG_HOME})+'\\n');
if(a.includes('--version'))console.log(process.env.FAKE_VERSION||'4.7.2.stable.fixture');
else if(process.env.FAIL_SCRIPT&&a.includes(process.env.FAIL_SCRIPT))console.error('SCRIPT ERROR: Parse Error: fixture failure');
`);
 fs.chmodSync(fake,0o755);
 const log=path.join(base,'calls');
 const run=extra=>spawnSync(process.execPath,[path.join(base,'tools/godot/cli.mjs'),'test'],{encoding:'utf8',env:{...process.env,GODOT_BIN:fake,CALL_LOG:log,...extra}});
 return {run,log,base};
}
test('CLI creates writable XDG directories, imports clean project, then runs both suites',t=>{
 const {run,log,base}=cliFixture(t);assert.equal(fs.existsSync(path.join(base,'godot/.godot')),false);
 const result=run();assert.equal(result.status,0,result.stderr);
 const calls=fs.readFileSync(log,'utf8').trim().split('\n').map(JSON.parse);
 assert.deepEqual(calls.map(c=>c.args.filter(a=>a.startsWith('--')||a.startsWith('res://'))),[
  ['--headless','--version'],['--path','--headless','--editor','--quit'],['--path','--headless','--script','res://tests/run.gd'],['--path','--headless','--script','res://tests/title_smoke.gd']
 ]);
 for(const c of calls)fs.accessSync(c.config,fs.constants.W_OK);
});
test('CLI rejects mismatched version and zero-exit script errors',t=>{
 const {run}=cliFixture(t);
 assert.equal(run({FAKE_VERSION:'4.7.1.stable'}).status,1);
 const error=run({FAIL_SCRIPT:'res://tests/run.gd'});
 assert.equal(error.status,1);assert.match(error.stderr,/errors or timeout detected/);
});
