import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {parseArgs,location,preflight,validateReport,taskXml} from './agent-loop.mjs';
const runner=fileURLToPath(new URL('./agent-loop.mjs',import.meta.url));
function command(exe,args,options={}) {
  const r=spawnSync(exe,args,{encoding:'utf8',windowsHide:true,...options});
  if(r.error || r.status!==0) throw new Error(r.error?.message || r.stderr || r.stdout);
  return r.stdout.trim();
}
function fixture(t) {
  const base=fs.mkdtempSync(path.join(os.tmpdir(),'hearthtable-loop-test-'));
  const project=path.join(base,"project with spaces & apostrophe's");fs.mkdirSync(project);
  const git=(...args)=>command('git',['-C',project,...args]);
  git('init','--initial-branch=automation/lite-improvements');git('config','user.email','fixture@example.invalid');git('config','user.name','Loop test');
  git('remote','add','origin','https://github.com/WonderingMage/Hearthtable.git');
  fs.writeFileSync(path.join(project,'project.godot'),'[application]\nconfig/edition="lite"\n');
  const mock=path.join(project,'fake codex.mjs');
  fs.writeFileSync(mock,`import fs from 'node:fs';import{spawnSync}from'node:child_process';
const args=process.argv.slice(2);
if(args.includes('--version')){console.log('codex-cli test-double');process.exit(0);}
if(args[0]==='login'){process.exit(0);}
const value=k=>args[args.indexOf(k)+1];const dir=value('-C');
const git=(...a)=>{const r=spawnSync('git',['-C',dir,...a],{encoding:'utf8'});if(r.status)throw Error(r.stderr);return r.stdout.trim();};
if(process.env.LOOP_TEST_MODE==='hang'){setInterval(()=>{},1000);}else{
if(process.env.LOOP_TEST_MODE==='dirty')fs.writeFileSync(dir+'/unfinished.txt','keep me');
if(process.env.LOOP_TEST_MODE==='accepted'){fs.writeFileSync(dir+'/improvement.txt','synthetic');git('add','improvement.txt');git('commit','-m','synthetic improvement');}
const status=process.env.LOOP_TEST_MODE==='blocked'?'blocked':process.env.LOOP_TEST_MODE==='accepted'?'accepted':'no_change';
const report={status,summary:'TEST DOUBLE ONLY',revision:git('rev-parse','HEAD'),role_reports:{builder:'mock builder',tester:'mock tester',critic:'mock critic'},tests:['mock check'],tester_approved:true,critic_approved:true,next_step:'fixture next step'};
if(process.env.LOOP_TEST_MODE==='bad-json')fs.writeFileSync(value('--output-last-message'),'not json');else fs.writeFileSync(value('--output-last-message'),JSON.stringify(report));
console.log('mock cycle completed');console.error('mock stderr preserved');}
`);
  git('add','.');git('commit','-m','fixture');
  const state=path.join(base,'state');
  const options={project,state,codex:mock};
  const invoke=(action,mode='',extra=[])=>spawnSync(process.execPath,[runner,action,'--project',project,'--state',state,'--codex',mock,...extra],{encoding:'utf8',windowsHide:true,timeout:20_000,env:{...process.env,LOOP_TEST_MODE:mode}});
  t.after(()=>fs.rmSync(base,{recursive:true,force:true}));
  return {project,state,mock,git,invoke,options};
}
test('arguments reject unknown actions and unbounded runtime',()=>{
  assert.equal(parseArgs([]).action,'doctor');assert.throws(()=>parseArgs(['publish']));assert.throws(()=>parseArgs(['run','--timeout-ms','999999999']));
});
test('doctor validates only the dedicated branch and preserves existing edits',t=>{
  const f=fixture(t);assert.equal(f.invoke('doctor').status,0);
  f.git('switch','-c','unrelated');const wrong=f.invoke('doctor');assert.notEqual(wrong.status,0);assert.match(wrong.stderr,/separate/);
  f.git('switch','automation/lite-improvements');fs.writeFileSync(path.join(f.project,'existing.txt'),'precious');
  assert.notEqual(f.invoke('run').status,0);assert.equal(fs.readFileSync(path.join(f.project,'existing.txt'),'utf8'),'precious');assert.ok(!fs.existsSync(f.state));
});
test('missing Git identity stops before starting an agent',t=>{
  const f=fixture(t);f.git('config','user.name','');f.git('config','user.email','');
  const result=f.invoke('run');assert.notEqual(result.status,0);assert.match(result.stderr,/commit identity/);assert.ok(!fs.existsSync(f.state));
});
test('reports cannot be placed in source, and an unrelated origin is refused',t=>{
  const f=fixture(t);assert.throws(()=>location({...f.options,state:path.join(f.project,'reports')}));
  f.git('remote','set-url','origin','https://github.com/example/other.git');assert.throws(()=>preflight(location(f.options)),/origin/);
});
test('a no-change cycle records state without calling a shell or changing source',t=>{
  const f=fixture(t);const before=f.git('rev-parse','HEAD');const r=f.invoke('run');assert.equal(r.status,0,r.stderr);
  assert.equal(f.git('rev-parse','HEAD'),before);assert.equal(f.git('status','--porcelain'),'');
  assert.equal(JSON.parse(fs.readFileSync(path.join(f.state,'ready.json'))).revision,before);
  assert.ok(!fs.existsSync(path.join(f.state,'running.json')));
  const run=fs.readdirSync(path.join(f.state,'runs'))[0];assert.match(fs.readFileSync(path.join(f.state,'runs',run,'console.txt'),'utf8'),/mock stderr preserved/);
});
test('accepted changes require actual new HEAD, evidence and approvals',t=>{
  const f=fixture(t);const before=f.git('rev-parse','HEAD');const r=f.invoke('run','accepted');assert.equal(r.status,0,r.stderr);const after=f.git('rev-parse','HEAD');assert.notEqual(after,before);
  const report=JSON.parse(fs.readFileSync(path.join(f.state,'latest.json')));
  assert.throws(()=>validateReport({...report,tester_approved:false},before,after),/approvals/);
  assert.throws(()=>validateReport({...report,tests:[]},before,after),/test evidence/);
  assert.throws(()=>validateReport({...report,status:'no_change'},before,after),/unexpectedly/);
});
test('blocked or unfinished work pauses future scheduled calls, preserving files',t=>{
  const f=fixture(t);const r=f.invoke('run','dirty');assert.notEqual(r.status,0);
  assert.equal(fs.readFileSync(path.join(f.project,'unfinished.txt'),'utf8'),'keep me');assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));
  // Clean up only this fixture's synthetic file to exercise the paused gate.
  fs.unlinkSync(path.join(f.project,'unfinished.txt'));
  const scheduled=f.invoke('run','accepted',['--scheduled']);assert.equal(scheduled.status,0,scheduled.stderr);assert.match(scheduled.stdout,/PAUSED/);assert.ok(!fs.existsSync(path.join(f.project,'improvement.txt')));
  assert.equal(f.invoke('run').status,0);assert.ok(!fs.existsSync(path.join(f.state,'PAUSED')));
});
test('bad JSON and explicit blockers never mark a cycle ready',t=>{
  const f=fixture(t);
  for(const mode of ['bad-json','blocked']) {const r=f.invoke('run',mode);assert.notEqual(r.status,0);assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));}
});
test('an existing cycle lock skips all agent work',t=>{
  const f=fixture(t);fs.mkdirSync(f.state);fs.writeFileSync(path.join(f.state,'workspace.json'),JSON.stringify({project:fs.realpathSync(f.project)}));
  fs.writeFileSync(path.join(f.state,'running.json'),JSON.stringify({pid:process.pid,token:'existing'}));
  const r=f.invoke('run','accepted');assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/SKIPPED/);assert.equal(fs.readFileSync(path.join(f.state,'running.json'),'utf8'),JSON.stringify({pid:process.pid,token:'existing'}));
  assert.ok(!fs.existsSync(path.join(f.project,'improvement.txt')));
});
test('a timed-out process is stopped and pauses future work',t=>{
  const f=fixture(t);const r=f.invoke('run','hang',['--timeout-ms','300']);assert.notEqual(r.status,0);assert.match(r.stderr,/time limit/);assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'running.json')));
});
test('schedule requires one successful manual cycle before installation',t=>{
  const f=fixture(t);const r=f.invoke('enable');assert.notEqual(r.status,0);assert.match(r.stderr,process.platform==='win32'?/successful manual cycle/:/Windows-only/);
});
test('native Windows scheduler accepts a disabled 30-minute, limited-user task',{skip:process.platform!=='win32'},t=>{
  const f=fixture(t);const loc=location(f.options);
  const xml=taskXml(loc).replace('<Settings>','<Settings>').replace('<StartWhenAvailable>false</StartWhenAvailable><Enabled>true</Enabled>','<StartWhenAvailable>false</StartWhenAvailable><Enabled>false</Enabled>');
  const encoded=Buffer.from(xml,'utf8').toString('base64');const name='Hearthtable loop TEST '+loc.id;
  const ps=`$ErrorActionPreference='Stop';$xml=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encoded}'));$xml=$xml.Replace('@OWNER_SID@',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value);try{Register-ScheduledTask -TaskName '${name}' -Xml $xml | Out-Null;$task=Get-ScheduledTask -TaskName '${name}';if($task.Settings.Enabled -or $task.Triggers[0].Repetition.Interval -ne 'PT30M' -or [string]$task.Settings.MultipleInstances -ne 'IgnoreNew' -or [string]$task.Principal.RunLevel -ne 'Limited'){throw 'Task settings incorrect'};Write-Output 'NATIVE_SCHEDULE_OK'}finally{Unregister-ScheduledTask -TaskName '${name}' -Confirm:$false -ErrorAction SilentlyContinue}`;
  const out=command('powershell.exe',['-NoProfile','-NonInteractive','-EncodedCommand',Buffer.from(ps,'utf16le').toString('base64')]);assert.match(out,/NATIVE_SCHEDULE_OK/);
});
test('native scheduled command launches Node with quoted paths and fake npm Codex',{skip:process.platform!=='win32'},t=>{
  const f=fixture(t);const loc=location(f.options);
  const appdata=path.join(path.dirname(f.project),'fake npm profile');
  const packageDir=path.join(appdata,'npm','node_modules','@openai','codex');fs.mkdirSync(path.join(packageDir,'bin'),{recursive:true});
  fs.writeFileSync(path.join(packageDir,'package.json'),'{"type":"module"}');fs.copyFileSync(f.mock,path.join(packageDir,'bin','codex.js'));
  const xml=taskXml(loc);const encoded=xml.match(/-EncodedCommand ([A-Za-z0-9+/=]+)/)[1];
  const output=command('powershell.exe',['-NoProfile','-NonInteractive','-EncodedCommand',encoded],{env:{...process.env,APPDATA:appdata,LOOP_TEST_MODE:''}});
  assert.match(output,/NO_CHANGE/);assert.equal(JSON.parse(fs.readFileSync(path.join(f.state,'latest.json'))).summary,'TEST DOUBLE ONLY');
});
