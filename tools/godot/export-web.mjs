// Credential-free candidate export. No tracked preset is ever temporarily modified.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {root} from '../lib/paths.mjs';
const bin=process.env.GODOT_BIN;
const template=process.env.GODOT_WEB_TEMPLATE;
if(!bin||!template)throw Error('Set GODOT_BIN (Godot 4.7.2) and GODOT_WEB_TEMPLATE (verified official web_nothreads_release.zip).');
const expected='33a52b6d9b1ce32d3683caaa3ea4b997a3f84c76a92a2e4a98a115b46da55d887854c9ef49bbf3b45b9629938110837978132c3a8cda26d278eb020bd6a9b8ea';
const hash=(file,algorithm='sha256')=>crypto.createHash(algorithm).update(fs.readFileSync(file)).digest('hex');
if(hash(template,'sha512')!==expected)throw Error('Template SHA512 differs from verified official 4.7.2 web_nothreads_release.zip.');
const dest=path.join(root,'build/web');
fs.mkdirSync(dest,{recursive:true});
const lock=path.join(dest,'.export.lock');
const lockFd=fs.openSync(lock,'wx');
const staging=fs.mkdtempSync(path.join(dest,'staging-'));
const project=path.join(staging,'project');
const env={...process.env,XDG_CONFIG_HOME:path.join(staging,'config'),XDG_DATA_HOME:path.join(staging,'data'),XDG_CACHE_HOME:path.join(staging,'cache')};
const output=path.join(dest,'valley-deck-0.1.0-web.zip');
let transcript='';
function run(args,timeout=180000){
 const r=spawnSync(bin,args,{env,encoding:'utf8',timeout,maxBuffer:32*1024*1024});
 const log=(r.stdout??'')+(r.stderr??'');transcript+=log;process.stdout.write(log);
 if(r.error||r.status!==0||/(?:SCRIPT ERROR:|(?:^|\n)\s*ERROR:|Parse Error:|Compile Error:)/.test(log))throw Error(`Godot failed: ${r.error?.message??r.status}`);
 return log;
}
try{
 const version=run(['--headless','--version']).trim();
 if(!/^4\.7\.2\./.test(version))throw Error('Godot 4.7.2 required.');
 const sync=spawnSync(process.execPath,['tools/resources/sync-godot.mjs','--verify'],{cwd:root,encoding:'utf8'});
 if(sync.status!==0)throw Error('Sync verification failed: '+sync.stdout+sync.stderr);
 fs.cpSync(path.join(root,'godot'),project,{recursive:true,filter:p=>!p.split(path.sep).includes('.godot')});
 const sourceFiles=[];
 function collect(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,entry.name);if(entry.isDirectory())collect(p);else if(entry.isFile())sourceFiles.push({path:path.relative(project,p).split(path.sep).join('/'),sha256:hash(p)});}}
 collect(project);sourceFiles.sort((a,b)=>a.path.localeCompare(b.path));
 const sourceManifest=JSON.stringify(sourceFiles,null,2)+'\n';
 fs.writeFileSync(path.join(dest,'source-manifest.json'),sourceManifest);
 const sourceSha256=crypto.createHash('sha256').update(sourceManifest).digest('hex');
 const templateDir=path.join(env.XDG_DATA_HOME,'godot/export_templates/4.7.2.stable');
 fs.mkdirSync(templateDir,{recursive:true});
 fs.copyFileSync(template,path.join(templateDir,'web_nothreads_release.zip'));
 const presetPath=path.join(project,'export_presets.cfg');
 const preset=fs.readFileSync(presetPath,'utf8').split('[preset.1]')[1].replaceAll('preset.1','preset.0').replace(/custom_template\/(debug|release)=""/g,(_,kind)=>`custom_template/${kind}=${JSON.stringify(path.resolve(template))}`);
 fs.writeFileSync(presetPath,'[preset.0]'+preset);
 // include_filter cannot retain the originals of recognized imported resources.
 // A staging-only editor export plugin explicitly adds raw decoder inputs.
 const addon=path.join(project,'addons/raw_export');fs.mkdirSync(addon,{recursive:true});
 fs.writeFileSync(path.join(addon,'plugin.cfg'),'[plugin]\nname="Raw export inputs"\ndescription="Preserve original WAV and font bytes"\nauthor="Valley Deck"\nversion="1.0"\nscript="plugin.gd"\n');
 fs.writeFileSync(path.join(addon,'plugin.gd'),`@tool
extends EditorPlugin
class RawExport extends EditorExportPlugin:
 func _get_name() -> String:
  return "ValleyRawInputs"
 func _export_file(file: String, _type: String, _features: PackedStringArray) -> void:
  if file.get_extension() in ["wav", "woff2"]:
   add_file(file, FileAccess.get_file_as_bytes(file), false)
var exporter: RawExport
func _enter_tree() -> void:
 exporter = RawExport.new()
 add_export_plugin(exporter)
func _exit_tree() -> void:
 remove_export_plugin(exporter)
`);
 fs.appendFileSync(path.join(project,'project.godot'),'\n[editor_plugins]\nenabled=PackedStringArray("res://addons/raw_export/plugin.cfg")\n');
 // Web-only feature overrides preserve synchronized stems and limiter; native source stays unchanged.
 const projectPath=path.join(project,'project.godot');
 fs.writeFileSync(projectPath,fs.readFileSync(projectPath,'utf8').replace('[application]', '[application]\nboot_splash/show_image=false\nboot_splash/image="res://resources/art/icon.app.png"')+'\n[audio]\ngeneral/default_playback_type.web=0\n');
 run(['--headless','--path',project,'--editor','--quit']);
 const packageName='valley-deck-0.1.0-web';
 const stagedPackage=path.join(staging,packageName);fs.mkdirSync(stagedPackage);
 run(['--headless','--path',project,'--export-release','Web Candidate',path.join(stagedPackage,'index.html')]);
 fs.copyFileSync(path.join(root,'docs/playtest/WEB.md'),path.join(stagedPackage,'README.md'));
 fs.cpSync(path.join(root,'third_party'),path.join(stagedPackage,'third_party'),{recursive:true});
 fs.writeFileSync(path.join(stagedPackage,'serve.py'),`#!/usr/bin/env python3
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os
os.chdir(Path(__file__).resolve().parent)
class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}
print('Open http://127.0.0.1:8060/ — Ctrl+C to stop', flush=True)
ThreadingHTTPServer(('127.0.0.1', 8060), Handler).serve_forever()
`);
 fs.copyFileSync(path.join(dest,'source-manifest.json'),path.join(stagedPackage,'source-manifest.json'));
 const packageFiles=[];
 function listPackage(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())listPackage(p);else packageFiles.push({path:path.relative(stagedPackage,p),bytes:fs.statSync(p).size,sha256:hash(p)});}}
 listPackage(stagedPackage);
 fs.writeFileSync(path.join(stagedPackage,'build-manifest.json'),JSON.stringify({engine:version,sourceManifestSha256:sourceSha256,templateSha512:expected,threads:false,webPlaybackType:'Stream',files:packageFiles},null,2)+'\n');
 const zipped=spawnSync('zip',['-q','-r',path.join(staging,'candidate.zip'),packageName],{cwd:staging,encoding:'utf8'});
 if(zipped.status!==0)throw Error('ZIP failed: '+zipped.stderr);
 fs.renameSync(path.join(staging,'candidate.zip'),output);
 const unpacked=path.join(dest,packageName);fs.rmSync(unpacked,{recursive:true,force:true});fs.renameSync(stagedPackage,unpacked);
 const manifest={status:'exported_candidate_pending_package_validation',engine:version,sourceManifestSha256:sourceSha256,templateSha512:expected,archive:path.basename(output),bytes:fs.statSync(output).size,sha256:hash(output),sha512:hash(output,'sha512'),presetSha256:hash(path.join(root,'godot/export_presets.cfg')),resourcePackSha256:hash(path.join(project,'resource-pack.json')),browserLaunchTested:false,threads:false,webPlaybackType:'Stream'};
 fs.writeFileSync(path.join(dest,'export-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log(JSON.stringify(manifest,null,2));
}finally{
 fs.writeFileSync(path.join(dest,'export.log'),transcript);
 fs.rmSync(staging,{recursive:true,force:true});
 fs.closeSync(lockFd);fs.unlinkSync(lock);
}
