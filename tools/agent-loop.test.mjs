import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {parseArgs,location,preflight,validateReport,taskXml,sessionConfig,probeRuntime,codexCommand} from './agent-loop.mjs';
import {pythonCommand} from './python-runtime.mjs';
import {toolHome} from './lite-local.mjs';
import {gitPrerequisite} from './agent-loop/git-prerequisite.mjs';
const runner=fileURLToPath(new URL('./agent-loop.mjs',import.meta.url));
function command(exe,args,options={}) {
  const r=spawnSync(exe,args,{encoding:'utf8',windowsHide:true,...options});
  if(r.error || r.status!==0) throw new Error(r.error?.message || r.stderr || r.stdout);
  return r.stdout.trim();
}
function fixture(t,parent=os.tmpdir()) {
  const base=fs.mkdtempSync(path.join(parent,'hearthtable-loop-test-'));
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
if(process.cwd()!==dir)throw Error('Agent process did not start in the project directory');
const config=args.find(x=>x.startsWith('shell_environment_policy.set.HEARTHTABLE_PYTHON='));
if(!config)throw Error('Python shell policy missing');
const python=JSON.parse(config.slice(config.indexOf('=')+1));
if(python!==process.env.HEARTHTABLE_PYTHON)throw Error('Agent and shell Python paths differ');
const toolsConfig=args.find(x=>x.startsWith('shell_environment_policy.set.HEARTHTABLE_TOOLCHAIN='));
if(!toolsConfig || JSON.parse(toolsConfig.slice(toolsConfig.indexOf('=')+1))!==process.env.HEARTHTABLE_TOOLCHAIN)throw Error('Godot toolchain handoff missing');
if(args.includes('sandbox')){
if(process.env.LOOP_TEST_MODE==='sandbox-fail'){console.error('synthetic sandbox Python visibility failure');process.exit(1);}
// This launcher unit fixture models prerequisite results; the optional native
// integration below runs the real script, Python and Godot inside Codex.
const result={passed:true,runtime:{exe:python},git:{passed:true},godot:{actual:{editor:true}}};
if(process.env.LOOP_TEST_MODE==='godot-fail'){result.passed=false;result.error='synthetic Godot startup failure';delete result.godot;}
fs.writeFileSync(value('--output'),JSON.stringify(result));
console.log(JSON.stringify(result));process.exit(result.passed?0:1);}
fs.writeFileSync(value('--output-last-message')+'.startup.json',JSON.stringify({cwd:process.cwd(),python,config}));
const git=(...a)=>{const r=spawnSync('git',['-C',dir,...a],{encoding:'utf8'});if(r.status)throw Error(r.stderr);return r.stdout.trim();};
if(process.env.LOOP_TEST_MODE==='hang'){setInterval(()=>{},1000);}else{
if(['dirty','blocked-dirty'].includes(process.env.LOOP_TEST_MODE))fs.writeFileSync(dir+'/unfinished.txt','keep me');
if(process.env.LOOP_TEST_MODE==='accepted'){fs.writeFileSync(dir+'/improvement.txt','synthetic');git('add','improvement.txt');git('commit','-m','synthetic improvement');}
const status=['blocked','blocked-dirty'].includes(process.env.LOOP_TEST_MODE)?'blocked':process.env.LOOP_TEST_MODE==='accepted'?'accepted':'no_change';
const report={status,summary:'TEST DOUBLE ONLY',revision:git('rev-parse','HEAD'),role_reports:{builder:'mock builder',tester:'mock tester',critic:'mock critic'},tests:['mock check'],tester_approved:true,critic_approved:true,next_step:'fixture next step'};
if(process.env.LOOP_TEST_MODE==='bad-json')fs.writeFileSync(value('--output-last-message'),'not json');else fs.writeFileSync(value('--output-last-message'),JSON.stringify(report));
console.log('mock cycle completed');console.error('mock stderr preserved');}
`);
  git('add','.');git('commit','-m','fixture');
  const state=path.join(base,'state');
  const options={project,state,codex:mock};
  const invoke=(action,mode='',extra=[])=>spawnSync(process.execPath,[runner,action,'--project',project,'--state',state,'--codex',mock,...extra],{encoding:'utf8',windowsHide:true,timeout:20_000,env:{...process.env,LOOP_TEST_MODE:mode}});
  t.after(()=>fs.rmSync(base,{recursive:true,force:true}));
  return {base,project,state,mock,git,invoke,options};
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
  const runtime=JSON.parse(fs.readFileSync(path.join(f.state,'runs',run,'runtime.json')));
  const startup=JSON.parse(fs.readFileSync(path.join(f.state,'runs',run,'report.json.startup.json')));
  assert.equal(startup.python,runtime.python);assert.equal(startup.cwd,fs.realpathSync(f.project));
  assert.ok(path.isAbsolute(runtime.python));
});
test('a broken Python configuration pauses before invoking any agent',t=>{
  const f=fixture(t),before=f.git('rev-parse','HEAD');
  const r=spawnSync(process.execPath,[runner,'run','--project',f.project,'--state',f.state,'--codex',f.mock],{encoding:'utf8',windowsHide:true,timeout:20000,env:{...process.env,HEARTHTABLE_PYTHON:process.execPath}});
  assert.notEqual(r.status,0);assert.match(r.stderr,/Configured Python could not be verified/);
  assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));
  for(const run of fs.readdirSync(path.join(f.state,'runs')))assert.ok(!fs.existsSync(path.join(f.state,'runs',run,'console.txt')));
  assert.equal(f.git('rev-parse','HEAD'),before);assert.equal(f.git('status','--porcelain'),'');
});
test('a probe leaves the loop paused and never invokes a model or creates readiness',t=>{
  const f=fixture(t);assert.equal(f.invoke('pause').status,0);
  const result=f.invoke('probe');assert.equal(result.status,0,result.stderr);assert.match(result.stdout,/PROBE_PASSED/);
  assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));
  const run=fs.readdirSync(path.join(f.state,'runs'))[0];
  assert.equal(JSON.parse(fs.readFileSync(path.join(f.state,'runs',run,'prerequisite.json'))).passed,true);
  assert.ok(!fs.existsSync(path.join(f.state,'runs',run,'console.txt')));
});
test('a sandbox prerequisite failure stops before all model work',t=>{
  const f=fixture(t),result=f.invoke('run','sandbox-fail');assert.notEqual(result.status,0);
  assert.match(result.stdout,/synthetic sandbox Python visibility failure/);assert.match(result.stderr,/before any model call/);
  const run=fs.readdirSync(path.join(f.state,'runs'))[0];assert.ok(!fs.existsSync(path.join(f.state,'runs',run,'console.txt')));
  assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));
});
test('a Godot prerequisite failure pauses before model usage',t=>{
  const f=fixture(t),before=f.git('rev-parse','HEAD'),result=f.invoke('run','godot-fail');
  assert.notEqual(result.status,0);assert.match(result.stderr,/synthetic Godot startup failure/);
  assert.ok(fs.existsSync(path.join(f.state,'PAUSED')));assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));
  const run=fs.readdirSync(path.join(f.state,'runs'))[0];assert.ok(!fs.existsSync(path.join(f.state,'runs',run,'console.txt')));
  assert.equal(f.git('rev-parse','HEAD'),before);assert.equal(f.git('status','--porcelain'),'');
});
test('the permission profile grants Python read access and keeps the workspace sandbox',t=>{
  const f=fixture(t),runtime=pythonCommand(),config=sessionConfig({project:f.project},runtime,f.state,f.git('rev-parse','--path-format=absolute','--git-common-dir'));
  assert.equal(config.profile,'hearthtable_loop');
  const profile=config.args.find(x=>x.startsWith('permissions.'));
  assert.ok(profile.includes('extends=":workspace"'));
  assert.ok(profile.includes(JSON.stringify(path.dirname(runtime.exe))+'="read"'));
  assert.ok(!profile.includes(JSON.stringify(path.dirname(runtime.exe))+'="write"'));
  assert.ok(profile.includes(JSON.stringify(config.toolchain)+'="read"'));
  assert.ok(!config.args.some(x=>x.includes('danger-full-access') || x.includes('bypass')));
});
test('linked worktrees explicitly authorize their own Git admin directory',t=>{
  const f=fixture(t),linked=path.join(f.base,"linked worktree & quote's");
  f.git('worktree','add','-b','automation/permission-check',linked,'HEAD');
  const common=fs.realpathSync.native(command('git',['-C',linked,'rev-parse','--path-format=absolute','--git-common-dir']));
  const gitdir=fs.realpathSync.native(command('git',['-C',linked,'rev-parse','--path-format=absolute','--git-dir']));
  assert.notEqual(gitdir,common);
  const config=sessionConfig({project:linked},pythonCommand(),f.state,common);
  const profile=config.args.find(x=>x.startsWith('permissions.'));
  assert.ok(profile.includes(JSON.stringify(gitdir)+'="write"'));
  assert.ok(profile.includes(JSON.stringify(common)+'="read"'));
  for(const name of ['objects','refs','logs'])assert.ok(profile.includes(JSON.stringify(path.join(common,name))+'="write"'));
  assert.ok(!profile.includes(JSON.stringify(path.join(linked,'.git'))+'="write"'),'The worktree pointer stays protected');
  // A normal checkout has the same gitdir/common path; duplicate TOML keys fail.
  const normal=sessionConfig({project:f.project},pythonCommand(),f.state,f.git('rev-parse','--path-format=absolute','--git-common-dir'));
  const metadataKey=JSON.stringify(normal.gitdir)+'="write"';
  assert.equal(normal.args.find(x=>x.startsWith('permissions.')).split(metadataKey).length-1,1);
});
test('the Git prerequisite leaves linked-worktree source, index, refs and metadata intact',t=>{
  const f=fixture(t),linked=path.join(f.base,'linked probe');
  f.git('worktree','add','-b','automation/probe-check',linked,'HEAD');
  const metadata=command('git',['-C',linked,'rev-parse','--path-format=absolute','--git-dir']);
  const index=fs.readFileSync(path.join(metadata,'index')),head=f.git('rev-parse','HEAD');
  const before=fs.readdirSync(metadata);
  const result=gitPrerequisite(linked);
  assert.equal(result.passed,true);assert.deepEqual(fs.readdirSync(metadata),before);
  assert.deepEqual(fs.readFileSync(path.join(metadata,'index')),index);assert.equal(f.git('rev-parse','HEAD'),head);
  for(const directory of result.checked)assert.ok(!fs.readdirSync(directory).some(name=>name.startsWith('.hearthtable-permission-probe-')));
  assert.equal(command('git',['-C',linked,'status','--porcelain']),'');
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
test('an unfinished blocked cycle retains its specific report instead of hiding it behind dirty status',t=>{
  const f=fixture(t),result=f.invoke('run','blocked-dirty');
  assert.notEqual(result.status,0);assert.match(result.stderr,/BLOCKED: TEST DOUBLE ONLY/);
  assert.doesNotMatch(result.stderr,/This workspace has uncommitted changes/);
  assert.equal(fs.readFileSync(path.join(f.project,'unfinished.txt'),'utf8'),'keep me');
  assert.ok(!fs.existsSync(path.join(f.state,'ready.json')));
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
test('native Windows scheduler accepts a disabled 10-minute, limited-user task',{skip:process.platform!=='win32'},t=>{
  const f=fixture(t);const loc=location(f.options);
  const xml=taskXml(loc).replace('<Settings>','<Settings>').replace('<StartWhenAvailable>false</StartWhenAvailable><Enabled>true</Enabled>','<StartWhenAvailable>false</StartWhenAvailable><Enabled>false</Enabled>');
  const encoded=Buffer.from(xml,'utf8').toString('base64');const name='Hearthtable loop TEST '+loc.id;
  const ps=`$ErrorActionPreference='Stop';$xml=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encoded}'));$xml=$xml.Replace('@OWNER_SID@',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value);try{Register-ScheduledTask -TaskName '${name}' -Xml $xml | Out-Null;$task=Get-ScheduledTask -TaskName '${name}';if($task.Settings.Enabled -or $task.Triggers[0].Repetition.Interval -ne 'PT10M' -or [string]$task.Settings.MultipleInstances -ne 'IgnoreNew' -or [string]$task.Principal.RunLevel -ne 'Limited'){throw 'Task settings incorrect'};Write-Output 'NATIVE_SCHEDULE_OK'}finally{Unregister-ScheduledTask -TaskName '${name}' -Confirm:$false -ErrorAction SilentlyContinue}`;
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
test('real Windows Codex sandbox validates Python, Godot, source, UI, network and compiled builds without models',{skip:process.platform!=='win32' || !process.env.HEARTHTABLE_REAL_CODEX,timeout:900000},async t=>{
  const f=fixture(t),runtime=pythonCommand(),base=path.join(process.env.LOCALAPPDATA,'Programs','Python');
  fs.mkdirSync(base,{recursive:true});const owned=fs.mkdtempSync(path.join(base,'HearthtableSandboxQA-')),install=path.join(owned,'Python313');
  t.after(()=>fs.rmSync(owned,{recursive:true,force:true}));
  // Copy only the installed interpreter/standard library into a per-user path
  // on this disposable VM. No downloads, third-party packages or personal data.
  fs.cpSync(path.dirname(runtime.exe),install,{recursive:true,filter:source=>!source.split(path.sep).some(part=>['site-packages','Scripts','__pycache__'].includes(part))});
  const copied=pythonCommand(path.join(install,'python.exe'));
  // The user's failure was reproduced with this per-user install invisible
  // inside the real sandbox. Apply only read/execute access to this disposable
  // tool installation, using Codex's own Windows group; never grant writes.
  command('icacls.exe',[install,'/grant','CodexSandboxUsers:(OI)(CI)(RX)','/T','/Q']);
  // Same scoped tool-only RX on this fresh VM. The owner already launched
  // Godot inside workers; never infer they need a grant or reinstall from CI.
  command('icacls.exe',[toolHome({}),'/grant','CodexSandboxUsers:(OI)(CI)(RX)','/T','/Q']);
  const run=path.join(f.base,'live sandbox reports');fs.mkdirSync(run);
  const source=path.dirname(path.dirname(runner)),loc={project:source},codex=codexCommand(process.env.HEARTHTABLE_REAL_CODEX);
  const common=command('git',['-C',source,'rev-parse','--path-format=absolute','--git-common-dir']);
  const before=command('git',['-C',source,'status','--porcelain']);
  // A sentinel on this disposable hosted VM proves normal user data is untouched.
  const normal=path.join(process.env.APPDATA,'Godot','app_userdata','Hearthtable Lite');
  assert.ok(!fs.existsSync(normal),'Refuse to touch existing normal campaign data');fs.mkdirSync(normal,{recursive:true});
  fs.writeFileSync(path.join(normal,'sentinel.txt'),'unchanged');
  const config=await probeRuntime(loc,codex,copied,run,common);
  const result=JSON.parse(fs.readFileSync(path.join(run,'prerequisite.json')));
  assert.equal(result.passed,true);assert.equal(result.runtime.exe,copied.exe);assert.equal(result.godot.actual.editor,true);
  console.log('Actual sandbox prerequisites: '+JSON.stringify(result));
  for(const [action,extra] of [['test',['--ui']],['network',[]],['build',[]]]) {
    const output=path.join(run,action);
    const args=[...codex.prefix,...config.args,'sandbox','-P',config.profile,'-C',source,'--',process.execPath,path.join(source,'tools','lite-local.mjs'),action,'--project',source,'--output',output,...extra];
    const result=spawnSync(codex.exe,args,{cwd:source,env:{...process.env,HEARTHTABLE_PYTHON:copied.exe,HEARTHTABLE_TOOLCHAIN:config.toolchain},encoding:'utf8',windowsHide:true,timeout:600000,maxBuffer:8000000});
    if(result.error || result.status!==0) {
      // Failure reports retain the actual Godot diagnostics, not only the wrapper.
      function logs(dir) {if(!fs.existsSync(dir))return;for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);if(entry.isDirectory())logs(file);else if(entry.name.endsWith('.log'))console.log(file+'\n'+fs.readFileSync(file,'utf8').slice(-3000));}}
      logs(output);
    }
    assert.equal(result.status,0,result.error?.message || result.stderr+'\n'+result.stdout);
    assert.match(result.stdout,/LITE_LOCAL_RESULT \d+ passed, 0 failed/);console.log(action+': '+result.stdout.slice(-2200));
  }
  assert.deepEqual(fs.readdirSync(normal),['sentinel.txt']);assert.equal(fs.readFileSync(path.join(normal,'sentinel.txt'),'utf8'),'unchanged');
  assert.equal(command('git',['-C',source,'status','--porcelain']),before);assert.equal(f.git('status','--porcelain'),'');
});
test('real Windows Codex sandbox stages and commits a linked-worktree change with its exact metadata grant',{skip:process.platform!=='win32' || !process.env.HEARTHTABLE_REAL_CODEX,timeout:300000},t=>{
  // Match the owner's Dev worktree outside the baseline writable TEMP root.
  const parent=path.join(process.env.USERPROFILE,'Dev');fs.mkdirSync(parent,{recursive:true});
  const f=fixture(t,parent),linked=path.join(f.base,"linked worktree & quote's");
  f.git('worktree','add','-b','automation/git-permission-proof',linked,'HEAD');
  const mainHead=f.git('rev-parse','HEAD'),common=f.git('rev-parse','--path-format=absolute','--git-common-dir');
  // Keep the harness entry in TEMP, whose parents Node can inspect. The Git
  // worktree/admin paths remain under Dev, matching the owner without granting
  // sandbox listing access to that private parent directory.
  const run=fs.mkdtempSync(path.join(os.tmpdir(),'hearthtable-git-permission-reports-'));
  t.after(()=>fs.rmSync(run,{recursive:true,force:true}));
  const config=sessionConfig({project:linked},pythonCommand(),run,common);
  const probe=path.join(run,'commit-probe.mjs');
  fs.writeFileSync(probe,`import fs from 'node:fs';import path from 'node:path';import{spawnSync}from'node:child_process';
const project=process.cwd(),file=path.join(project,'metadata-proof.txt');
const git=(...args)=>{const r=spawnSync('git',['-C',project,'-c','commit.gpgsign=false',...args],{encoding:'utf8'});if(r.error||r.status!==0)throw Error(r.error?.message||r.stderr);return r.stdout.trim();};
fs.writeFileSync(file,'Synthetic sandbox permission proof.');
git('add','--','metadata-proof.txt');git('commit','-m','Synthetic linked-worktree sandbox proof');
let protectedPointer=false;try{const fd=fs.openSync(path.join(project,'.git'),'r+');fs.closeSync(fd);}catch(error){if(!['EACCES','EPERM'].includes(error.code))throw error;protectedPointer=true;}
if(!protectedPointer)throw Error('The worktree Git pointer must remain protected');
console.log('GIT_SANDBOX_COMMIT_OK '+git('rev-parse','HEAD'));
`);
  const codex=codexCommand(process.env.HEARTHTABLE_REAL_CODEX);
  // Evaluate the builtin-only harness directly. Node 22's main-module realpath
  // walker otherwise tries to list private Dev/AppData ancestors before Git
  // starts, regardless of the accessible script's exact directory grant.
  const invoke=args=>spawnSync(codex.exe,[...codex.prefix,...args,'sandbox','-P',config.profile,'-C',linked,'--',process.execPath,'--input-type=module','-e',fs.readFileSync(probe,'utf8')],{cwd:linked,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:2000000});
  const oldEntries=[[path.dirname(pythonCommand().exe),'read'],[config.toolchain,'read'],[run,'write'],[common,'write']];
  const oldProfile='permissions.'+config.profile+'={extends=":workspace",filesystem={'+oldEntries.map(([dir,mode])=>JSON.stringify(dir)+'='+JSON.stringify(mode)).join(',')+'}}';
  const oldArgs=config.args.map(arg=>arg.startsWith('permissions.')?oldProfile:arg);
  const denied=invoke(oldArgs);
  assert.notEqual(denied.status,0);assert.match((denied.stderr||'')+(denied.stdout||''),/index\.lock/);
  console.log('Reproduced linked-worktree index.lock denial with the old broader grant.');
  const allowed=invoke(config.args);
  assert.equal(allowed.status,0,allowed.error?.message || allowed.stderr+'\n'+allowed.stdout);
  assert.match(allowed.stdout,/GIT_SANDBOX_COMMIT_OK/);console.log(allowed.stdout.trim());
  assert.notEqual(command('git',['-C',linked,'rev-parse','HEAD']),mainHead);
  assert.equal(command('git',['-C',linked,'status','--porcelain']),'');assert.equal(f.git('rev-parse','HEAD'),mainHead);assert.equal(f.git('status','--porcelain'),'');
});
