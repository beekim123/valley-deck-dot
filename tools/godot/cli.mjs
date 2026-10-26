import fs from 'node:fs';
import path from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import {root} from '../lib/paths.mjs';
const mode=process.argv[2]??'dev';
if(!['dev','test','sim','shots','import'].includes(mode))throw Error('Unknown Godot mode '+mode);
let bin=process.env.GODOT_BIN;
if(!bin){const local=path.join(root,'Godot.app/Contents/MacOS/Godot');bin=fs.existsSync(local)?local:'godot';}
const cache=path.join(root,'.cache/godot-home');
for(const d of ['config','data','cache']){const p=path.join(cache,d);fs.mkdirSync(p,{recursive:true});fs.accessSync(p,fs.constants.W_OK);}
const env={...process.env,XDG_CONFIG_HOME:path.join(cache,'config'),XDG_DATA_HOME:path.join(cache,'data'),XDG_CACHE_HOME:path.join(cache,'cache')};
const version=spawnSync(bin,['--headless','--version'],{encoding:'utf8',env,timeout:10000});
if(version.error||version.status!==0||!/^4\.7\.2(?:\.|$)/.test(version.stdout?.trim()??'')){console.error('Godot 4.7.2 required. Set GODOT_BIN to your editor executable. Found: '+(version.stdout?.trim()||version.error?.message));process.exit(1);}
const base=['--path',path.join(root,'godot')];
async function run(args,timeout=120000) {
 return new Promise((resolve,reject)=>{
  const child=spawn(bin,[...base,...args],{env,stdio:['inherit','pipe','pipe']});
  let failed=false,tail='';
  const timer=timeout?setTimeout(()=>{failed=true;console.error(`Godot timed out after ${timeout} ms`);child.kill('SIGKILL');},timeout):null;
  const output=(stream,chunk)=>{
   stream.write(chunk);tail=(tail+chunk.toString()).slice(-8192);
   if(/(?:SCRIPT ERROR:|(?:^|\n)\s*ERROR:|Parse Error:|Compile Error:)/.test(tail))failed=true;
  };
  child.stdout.on('data',chunk=>output(process.stdout,chunk));
  child.stderr.on('data',chunk=>output(process.stderr,chunk));
  child.on('error',error=>{clearTimeout(timer);reject(error);});
  child.on('close',(code,signal)=>{clearTimeout(timer);if(failed||code!==0||signal)reject(Error(`Godot failed (${signal??code}${failed?', errors or timeout detected':''})`));else resolve();});
 });
}
try {
 if(mode==='sim'&&!fs.existsSync(path.join(root,'godot/tests/sim.gd')))throw Error('D1 simulator not implemented; not a passing simulation.');
 // A clean checkout has no import cache or global class registry yet.
 await run(['--headless','--editor','--quit']);
 if(mode==='test') {
  await run(['--headless','--script','res://tests/run.gd']);
  await run(['--headless','--script','res://tests/title_smoke.gd']);
  for(const test of ['tests/rules_d1.gd','tests/save_validation.gd','scripts/view/ui_smoke.gd'])if(fs.existsSync(path.join(root,'godot',test)))await run(['--headless','--script','res://'+test]);
 }else if(mode==='sim')await run(['--headless','--script','res://tests/sim.gd'],600000);
 else if(mode==='shots')await run(['--','--shots','--shots-dir='+path.join(root,'artifacts/screenshots')]);
 else if(mode==='dev')await run([],0);
}catch(error){console.error(error.message);process.exitCode=1;}
