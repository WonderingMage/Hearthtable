#!/usr/bin/env node
// Pinned local Godot setup, isolated tests and candidate builds. No model calls.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn,spawnSync} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
import {Readable} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import {pythonCommand} from './python-runtime.mjs';
import {godotLog} from './godot-log.mjs';
export {pythonCommand} from './python-runtime.mjs';

const script=fileURLToPath(import.meta.url), root=path.dirname(path.dirname(script));
const version='4.5.1', official='4.5.1.stable.official.f62fdbde1';
const baseURL='https://github.com/godotengine/godot/releases/download/4.5.1-stable/';
const zipName='Godot_v4.5.1-stable_win64.exe.zip', tpzName='Godot_v4.5.1-stable_export_templates.tpz';
const core=['lite','updates','pdf_import'], ui=['lite_ui','pdf_import_ui','character_review_ui'];
const bad=/(?:^|\n)(?:SCRIPT ERROR:|ERROR:|.*Parse Error:|.*FAIL )/;
const summary=/\b\w+ (\d+) passed, (\d+) failed/g;
export function options(args) {
  const o={action:args.shift() || 'doctor',project:root,ui:false,suite:null};
  const keys={'--project':'project','--output':'output','--godot':'godot','--templates':'templates','--suite':'suite','--toolchain':'toolchain','--python':'python'};
  while(args.length) {const key=args.shift();if(key==='--ui'){o.ui=true;continue;}if(!keys[key] || !args.length)throw Error('Unknown or incomplete option: '+key);o[keys[key]]=args.shift();}
  if(!['setup','doctor','test','network','build'].includes(o.action))throw Error('Use setup, doctor, test, network or build.');
  if(o.suite && ![...core,...ui].includes(o.suite))throw Error('Choose a supported Lite suite.');
  return o;
}
export function checkedProject(text) {
  if(!/^config\/name="Hearthtable Lite"\s*$/m.test(text) || !/^config\/edition="lite"\s*$/m.test(text))throw Error('Expected the unchanged Lite application identity.');
  if(/^config\/(?:use_custom_user_dir|custom_user_dir_name|project_settings_override|name\.)/m.test(text))throw Error('Custom user-directory/identity overrides need separate isolation review.');
}
export function git(project,...args) {
  const r=spawnSync('git',['-C',project,...args],{encoding:'utf8',windowsHide:true});if(r.error || r.status!==0)throw Error('Git failed: '+(r.error?.message || r.stderr));return r.stdout.trim();
}
function resolvedTarget(target) {
  // Resolve the accessible file directly, without enumerating private parents.
  if(fs.existsSync(target))return fs.realpathSync.native(target);
  const parent=path.dirname(target);
  return parent===target?target:path.join(resolvedTarget(parent),path.basename(target));
}
export function outside(project,target) {
  project=resolvedTarget(path.resolve(project));target=resolvedTarget(path.resolve(target));
  const relative=path.relative(project,target);
  if(relative==='' || (!relative.startsWith('..'+path.sep) && relative!=='..' && !path.isAbsolute(relative)))throw Error('Output must be outside the source checkout.');
}
export function toolHome(o) {return path.resolve(o.toolchain || process.env.HEARTHTABLE_TOOLCHAIN || path.join(process.env.LOCALAPPDATA || path.join(os.homedir(),'.local','share'),'HearthtableCodexTools','Godot-4.5.1'));}
async function hash(file,algorithm='sha256') {const h=createHash(algorithm);for await(const chunk of fs.createReadStream(file))h.update(chunk);return h.digest('hex');}
function ps(body) {
  const r=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-EncodedCommand',Buffer.from("$ErrorActionPreference='Stop';"+body,'utf16le').toString('base64')],{encoding:'utf8',windowsHide:true,timeout:180000});
  if(r.error || r.status!==0)throw Error('Windows setup: '+(r.error?.message || r.stderr));return r.stdout.trim();
}
async function download(name,folder,expected) {
  const file=path.join(folder,name);
  if(fs.existsSync(file)) {if(await hash(file,'sha512')!==expected)throw Error('Cached official download has a checksum mismatch: '+file);return file;}
  console.log('Downloading '+name+' ...');
  const part=file+'.partial-'+randomUUID();
  try {const response=await fetch(baseURL+name);if(!response.ok)throw Error('Official download returned HTTP '+response.status);await pipeline(Readable.fromWeb(response.body),fs.createWriteStream(part,{flags:'wx'}));if(await hash(part,'sha512')!==expected)throw Error('Official SHA-512 checksum mismatch.');fs.renameSync(part,file);}
  finally {fs.rmSync(part,{force:true});}
  return file;
}
async function extract(zip,destination,entries) {
  const data=Buffer.from(JSON.stringify({zip,destination,entries})).toString('base64');
  ps(`Add-Type -AssemblyName System.IO.Compression.FileSystem;$data=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${data}'))|ConvertFrom-Json;$archive=[IO.Compression.ZipFile]::OpenRead($data.zip);try{foreach($item in $data.entries){$entry=$archive.GetEntry($item.from);if(!$entry){throw 'Missing official archive entry'};$target=Join-Path $data.destination $item.to;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null;[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)}}finally{$archive.Dispose()}`);
}
export async function setup(o) {
  if(process.platform!=='win32')throw Error('Automatic toolchain setup is for Windows; other platforms may use an explicit --godot editor.');
  const home=toolHome(o);outside(fs.realpathSync.native(o.project),home);
  if(fs.existsSync(home)) {await engine(o);console.log('Verified existing Godot '+official+' and export templates.');return;}
  const parent=path.dirname(home);fs.mkdirSync(parent,{recursive:true});
  const lock=home+'.setup-lock';let fd;
  try {fd=fs.openSync(lock,'wx');} catch {throw Error('Setup is already running or left a lock: '+lock);}
  const stage=home+'.staging-'+randomUUID();
  try {
    const response=await fetch(baseURL+'SHA512-SUMS.txt');if(!response.ok)throw Error('Official checksums unavailable: HTTP '+response.status);
    const sums=await response.text();if(sums.length>1000000)throw Error('Unexpected checksum list.');
    const expected=name=>{const entry=sums.split(/\r?\n/).map(x=>x.trim().split(/\s+/)).find(x=>x[1]?.replace(/^\*/,'')===name);if(!entry || !/^[a-fA-F0-9]{128}$/.test(entry[0]))throw Error('Missing official checksum: '+name);return entry[0].toLowerCase();};
    const cache=path.join(parent,'official-downloads');fs.mkdirSync(cache,{recursive:true});
    const archive=await download(zipName,cache,expected(zipName));const templates=await download(tpzName,cache,expected(tpzName));
    fs.mkdirSync(stage);
    const editorFiles=['Godot_v4.5.1-stable_win64.exe','Godot_v4.5.1-stable_win64_console.exe'];
    await extract(archive,stage,editorFiles.map(name=>({from:name,to:'bin/'+name})));
    const templateFiles=['version.txt','windows_release_x86_64.exe','windows_release_x86_64_console.exe'];
    await extract(templates,stage,templateFiles.map(name=>({from:'templates/'+name,to:'templates/'+name})));
    const files={};for(const rel of [...editorFiles.map(x=>'bin/'+x),...templateFiles.map(x=>'templates/'+x)])files[rel]=await hash(path.join(stage,rel));
    fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify({engine:official,archives:{[zipName]:expected(zipName),[tpzName]:expected(tpzName)},files},null,2));
    fs.renameSync(stage,home);await engine(o);console.log('SETUP_OK: Godot '+official+' and Windows export templates are ready.\nTools: '+home+'\nNo game, test or agent was started.');
  } finally {if(fs.existsSync(stage))fs.rmSync(stage,{recursive:true,force:true});fs.closeSync(fd);fs.unlinkSync(lock);}
}
export async function engine(o) {
  if(o.godot) {
    const exe=fs.realpathSync.native(o.godot);const r=spawnSync(exe,['--version'],{encoding:'utf8',windowsHide:true});if(r.status!==0 || !r.stdout.trim().startsWith(official))throw Error('Use the official Godot 4.5.1 editor.');return {exe,templates:o.templates && fs.realpathSync.native(o.templates)};
  }
  const home=toolHome(o), manifestFile=path.join(home,'manifest.json');
  if(!fs.existsSync(manifestFile))throw Error('Godot is not set up or its manifest is inaccessible: '+manifestFile+'. Verify it outside the sandbox before considering setup; do not reinstall working tools.');
  const manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
  if(manifest.engine!==official || !manifest.files || Object.keys(manifest.files).length!==5)throw Error('Unexpected toolchain manifest.');
  for(const rel of Object.keys(manifest.files))if(path.isAbsolute(rel) || rel.split(/[\\/]/).includes('..'))throw Error('Unexpected toolchain manifest path.');
  for(const [rel,wanted] of Object.entries(manifest.files))if(await hash(path.join(home,rel))!==wanted)throw Error('Godot toolchain file changed: '+rel);
  const exe=path.join(home,'bin','Godot_v4.5.1-stable_win64_console.exe');
  const r=spawnSync(exe,['--version'],{encoding:'utf8',windowsHide:true,timeout:15000});
  if(r.status!==0 || !r.stdout.trim().startsWith(official))throw Error('Pinned Godot editor did not start correctly.');
  return {exe,templates:path.join(home,'templates')};
}
export function processEnv(base) {
  for(const dir of ['data','config','cache','temp'])fs.mkdirSync(path.join(base,dir),{recursive:true});
  return {...process.env,APPDATA:path.join(base,'data'),LOCALAPPDATA:path.join(base,'cache'),TEMP:path.join(base,'temp'),TMP:path.join(base,'temp'),XDG_DATA_HOME:path.join(base,'data'),XDG_CONFIG_HOME:path.join(base,'config'),XDG_CACHE_HOME:path.join(base,'cache')};
}
async function run(exe,args,env,log,timeout=300000,godot=false) {
  const stream=fs.createWriteStream(log,{flags:'wx'});let text='';
  const child=spawn(exe,args,{env,windowsHide:true,stdio:['ignore','pipe','pipe']});let timedOut=false;
  const timer=setTimeout(()=>{if(child.exitCode!==null || child.signalCode!==null || !child.pid)return;timedOut=true;if(process.platform==='win32')spawnSync('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});else child.kill('SIGTERM');},timeout);
  for(const input of [child.stdout,child.stderr])input.on('data',chunk=>{stream.write(chunk);text+=chunk.toString();if(text.length>16000000)text=text.slice(-16000000);});
  try {const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});const assessment=godot?godotLog(text):{failed:bad.test(text)};if(timedOut || code!==0 || assessment.failed)throw Error('Validation failed'+(timedOut?' (timeout)':'')+'; inspect '+log+'\n'+text.slice(godot?-1800:-6000));if(assessment.builtinFallback)console.log('Godot verified bundled CA fallback; original certificate-store diagnostic retained in '+log);return text;}
  finally {clearTimeout(timer);await new Promise(resolve=>stream.end(resolve));}
}
function runGodot(exe,args,env,log,timeout=300000) {return run(exe,['--verbose',...args],env,log,timeout,true);}
export async function isolated(base,exe,editor=true,releaseProbe=null) {
  const env=processEnv(base),probe=path.join(base,'probe');fs.mkdirSync(probe);
  fs.writeFileSync(path.join(probe,'project.godot'),'[application]\nconfig/name="Hearthtable Lite"\n');
  fs.writeFileSync(path.join(probe,'probe.gd'),'extends SceneTree\nfunc _initialize():\n\tprint("SAFE_PROBE="+JSON.stringify({"path":OS.get_user_data_dir(),"editor":OS.has_feature("editor"),"version":Engine.get_version_info()}))\n\tquit()\n');
  const args=releaseProbe?['--headless','--script',path.join(probe,'probe.gd')]:['--headless','--path',probe,'--script','res://probe.gd'];
  const text=await runGodot(releaseProbe || exe,args,env,path.join(base,'probe.log'),30000);
  const match=text.match(/SAFE_PROBE=(.+)/);const actual=match && JSON.parse(match[1]);
  const expected=path.resolve(base,'data',process.platform==='win32'?'Godot':'godot','app_userdata','Hearthtable Lite');
  const normalize=value=>process.platform==='win32'?path.resolve(value).toLowerCase():path.resolve(value);
  const info=actual?.version;
  if(!actual || normalize(actual.path)!==normalize(expected) || actual.editor!==editor || info?.major!==4 || info.minor!==5 || info.patch!==1 || info.status!=='stable' || info.build!=='official' || !info.hash.startsWith('f62fdbde1'))throw Error('Cannot prove disposable Godot user-data isolation. No campaign test was started.');
  fs.writeFileSync(path.join(base,'isolation.json'),JSON.stringify({actual,expected,builtinFallback:godotLog(text).builtinFallback},null,2));return {env,probe,expected};
}
export function snapshot(project,output) {
  const copy=path.join(output,'project');fs.mkdirSync(copy);
  const list=spawnSync('git',['-C',project,'ls-files','-z'],{encoding:'utf8'});if(list.status!==0)throw Error('Cannot enumerate tracked source.');
  for(const rel of list.stdout.split('\0').filter(Boolean)) {
    if(rel==='override.cfg' || rel.startsWith('.godot/'))throw Error('Unexpected project override/cache in tracked source.');
    const from=path.resolve(project,rel);outside(copy,from);
    if(!fs.existsSync(from))continue;
    if(fs.lstatSync(from).isSymbolicLink())throw Error('Review source symlinks before using this test harness: '+rel);
    const to=path.resolve(copy,rel);if(path.relative(copy,to).startsWith('..'))throw Error('Unsafe source path.');
    fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(from,to);
  }
  checkedProject(fs.readFileSync(path.join(copy,'project.godot'),'utf8'));return copy;
}
function templatesAt(env,templates) {
  if(!templates)throw Error('Matching export templates are required. Run setup first.');
  const base=process.platform==='win32'?env.APPDATA:env.XDG_DATA_HOME;
  const target=path.join(base,process.platform==='win32'?'Godot':'godot','export_templates','4.5.1.stable');fs.mkdirSync(target,{recursive:true});
  for(const name of ['version.txt','windows_release_x86_64.exe','windows_release_x86_64_console.exe'])fs.copyFileSync(path.join(templates,name),path.join(target,name));
}
export async function main(args=process.argv.slice(2)) {
  const o=options([...args]);o.project=fs.realpathSync.native(o.project);checkedProject(fs.readFileSync(path.join(o.project,'project.godot'),'utf8'));
  if(fs.existsSync(path.join(o.project,'override.cfg')))throw Error('Review/remove project override.cfg before isolated testing.');
  if(o.action==='setup'){await setup(o);return;}
  const tool=await engine(o);
  if(o.action==='doctor') {console.log('Godot: '+official+'\nEditor: '+tool.exe+'\nTemplates: '+(tool.templates || 'not configured'));try{const py=pythonCommand(o.python);console.log('Python: '+py.exe+' ('+py.version+', ready)');}catch(error){console.log('Python: NOT READY — '+error.message);process.exitCode=1;}console.log('No game or agent was started.');return;}
  if(o.action==='build' && git(o.project,'status','--porcelain'))throw Error('Build requires a clean candidate commit, after testing and review.');
  const before=git(o.project,'rev-parse','HEAD');
  const output=path.resolve(o.output || path.join(process.env.LOCALAPPDATA || os.tmpdir(),'HearthtableCodexQA',new Date().toISOString().replace(/[:.]/g,'-')+'-'+randomUUID().slice(0,8)));
  outside(o.project,output);outside(git(o.project,'rev-parse','--path-format=absolute','--git-common-dir'),output);
  if(fs.existsSync(output))throw Error('Choose a new output folder; existing results are never overwritten.');
  fs.mkdirSync(output,{recursive:true});console.log('Results: '+output);
  const copy=snapshot(o.project,output);const imported=await isolated(path.join(output,'import'),tool.exe);
  await runGodot(tool.exe,['--headless','--path',copy,'--editor','--import'],imported.env,path.join(output,'import.log'));
  const results={};
  async function suite(name,exe=tool.exe,probe=null) {
    const iso=await isolated(path.join(output,name+(probe?'-compiled':'')),tool.exe,!probe,probe);
    const graphical=ui.includes(name);
    const text=await runGodot(exe,['--audio-driver','Dummy',...(!graphical?['--headless']:[]),'--path',copy,'--script',path.join(copy,'tests',name+'.gd'),'--','--qa'],iso.env,path.join(output,name+(probe?'-compiled':'')+'.log'),graphical?600000:180000);
    const matches=[...text.matchAll(summary)];if(!matches.length || matches.some(m=>Number(m[1])===0 || Number(m[2])!==0))throw Error('Missing/failed assertion summary: '+name);
    const passed=matches.reduce((sum,m)=>sum+Number(m[1]),0);results[name+(probe?'-compiled':'')]=passed;console.log(name+(probe?' (native compiled)':'')+': '+passed+' passed');
  }
  if(o.action==='test')for(const name of o.suite?[o.suite]:o.ui?[...core,...ui]:core)await suite(name);
  if(o.action==='network') {
    const py=pythonCommand(o.python);const text=await run(py.exe,[...py.prefix,'-I',path.join(copy,'tools','test_lite_network.py'),'--engine',tool.exe,'--output',path.join(output,'network'),...(o.ui?['--ui']:[])],process.env,path.join(output,'network.log'),600000);
    const matches=[...text.matchAll(summary)];if(!matches.length || matches.some(m=>Number(m[2])!==0))throw Error('Network verification did not pass.');results.network=Number(matches.at(-1)[1]);console.log('Network: '+results.network+' passed');
  }
  if(o.action==='build') {
    const py=pythonCommand(o.python);templatesAt(imported.env,tool.templates);
    const program=path.join(output,'Hearthtable_Lite_Portable.exe'),pack=path.join(output,'Lite_Application.pck');
    await runGodot(tool.exe,['--headless','--path',copy,'--export-release','Windows Desktop',program],imported.env,path.join(output,'export-windows.log'));
    await runGodot(tool.exe,['--headless','--path',copy,'--export-pack','Windows Desktop',pack],imported.env,path.join(output,'export-pack.log'));
    const product=/config\/version="([^"]+)"/.exec(fs.readFileSync(path.join(copy,'project.godot'),'utf8'))[1];
    const protocol=Number(/const PROTOCOL\s*=\s*(\d+)/.exec(fs.readFileSync(path.join(copy,'scripts','world.gd'),'utf8'))[1]);
    const update=path.join(output,'Hearthtable-Lite-'+product+'.hearthupdate');
    await run(py.exe,[...py.prefix,'-I',path.join(copy,'tools','make_update.py'),'--pack',pack,'--output',update,'--version',product,'--commit',before,'--protocol',String(protocol)],process.env,path.join(output,'package-update.log'));
    // Export a minimal no-autoload probe from the same official release template
    // before loading World from the candidate EXE on native Windows.
    if(process.platform==='win32') {
      const tiny=imported.probe;fs.copyFileSync(path.join(copy,'export_presets.cfg'),path.join(tiny,'export_presets.cfg'));
      await runGodot(tool.exe,['--headless','--path',tiny,'--editor','--import'],imported.env,path.join(output,'probe-import.log'));
      const probeExe=path.join(output,'Isolation_Probe.exe');
      await runGodot(tool.exe,['--headless','--path',tiny,'--export-release','Windows Desktop',probeExe],imported.env,path.join(output,'probe-export.log'));
      for(const name of core)await suite(name,program,probeExe);
    }
    if(git(o.project,'status','--porcelain') || git(o.project,'rev-parse','HEAD')!==before)throw Error('Source changed during build. Do not distribute these candidate artifacts.');
    fs.writeFileSync(path.join(output,'build-manifest.json'),JSON.stringify({commit:before,dirty:false,engine:official,version:product,protocol,filename:path.basename(program),sha256:await hash(program),update:{filename:path.basename(update),sha256:await hash(update)},assertions:results,publication:false},null,2));
    console.log('Prepared candidate EXE + matching Settings update. Not a release; do not install unpublished updates into your real campaign.');
  }
  fs.writeFileSync(path.join(output,'results.json'),JSON.stringify({source:before,engine:official,assertions:results},null,2));
  console.log('LITE_LOCAL_RESULT '+Object.values(results).reduce((a,b)=>a+b,0)+' passed, 0 failed\nResults: '+output);
}
if(process.argv[1] && path.resolve(process.argv[1])===script)main().catch(error=>{console.error(error.message);process.exitCode=1;});
