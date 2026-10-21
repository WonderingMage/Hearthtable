#!/usr/bin/env node
// Opt-in local runner. Importing this module never starts agents or a schedule.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash, randomUUID} from 'node:crypto';
import {spawn, spawnSync} from 'node:child_process';
import {pythonCommand} from './python-runtime.mjs';
import {toolHome} from './lite-local.mjs';

const script = fileURLToPath(import.meta.url);
const tools = path.dirname(script);
const branch = 'automation/lite-improvements';
export function parseArgs(args) {
  const options={action:args.shift() || 'doctor',project:path.dirname(tools),scheduled:false,timeout:40*60_000};
  const values={'--project':'project','--state':'state','--codex':'codex','--timeout-ms':'timeout'};
  while(args.length) {
    const flag=args.shift();
    if(flag==='--scheduled') {options.scheduled=true;continue;}
    if(!values[flag] || !args.length) throw new Error('Unknown or incomplete option: '+flag);
    options[values[flag]]=args.shift();
  }
  options.timeout=Number(options.timeout);
  if(!Number.isFinite(options.timeout) || options.timeout<100 || options.timeout>45*60_000) throw new Error('Timeout must be between 100 ms and 45 minutes.');
  if(!['doctor','probe','run','enable','pause','status','unlock'].includes(options.action)) throw new Error('Use doctor, probe, run, enable, pause, status or unlock.');
  return options;
}
export function location(options) {
  const project=fs.realpathSync(options.project);
  const id=createHash('sha256').update(process.platform==='win32'?project.toLowerCase():project).digest('hex').slice(0,12);
  const base=process.env.LOCALAPPDATA || path.join(os.homedir(),'.local','state');
  const state=path.resolve(options.state || path.join(base,'HearthtableCodexLoop',id));
  const relative=path.relative(project,state);
  if(relative==='' || (!relative.startsWith('..'+path.sep) && relative!=='..' && !path.isAbsolute(relative))) throw new Error('Reports must be outside the source checkout.');
  return {project,state,id,task:'Hearthtable Lite agents '+id};
}
function git(project,...args) {
  const r=spawnSync('git',['-C',project,...args],{encoding:'utf8',windowsHide:true});
  if(r.error || r.status!==0) throw new Error('Git failed: '+(r.error?.message || r.stderr.trim()));
  return r.stdout.trim();
}
export function preflight(loc) {
  if(git(loc.project,'branch','--show-current')!==branch) throw new Error('Use the separate '+branch+' workspace. No agent was started.');
  if(git(loc.project,'status','--porcelain')) throw new Error('This workspace has uncommitted changes. Preserve/review them before continuing; nothing was discarded.');
  const project=fs.readFileSync(path.join(loc.project,'project.godot'),'utf8');
  if(!project.includes('config/edition="lite"')) throw new Error('Expected the Hearthtable Lite project.');
  const remote=git(loc.project,'remote','get-url','origin').replace(/\.git$/,'').replace(/\/$/,'');
  if(!['https://github.com/WonderingMage/Hearthtable','git@github.com:WonderingMage/Hearthtable'].includes(remote)) throw new Error('Expected the WonderingMage/Hearthtable origin.');
  try {git(loc.project,'var','GIT_AUTHOR_IDENT');git(loc.project,'var','GIT_COMMITTER_IDENT');}
  catch {throw new Error('Git needs a commit identity before agents can save their work. Configure a repository-local user.name and user.email, then retry doctor.');}
  return git(loc.project,'rev-parse','HEAD');
}
export function codexCommand(override) {
  if(override) {
    const resolved=fs.realpathSync(override);
    if(/\.[cm]?js$/i.test(resolved)) return {exe:process.execPath,prefix:[resolved]};
    if(/\.(cmd|bat|ps1)$/i.test(resolved)) throw new Error('Use the Codex .js entry point or native .exe, not a shell shim.');
    return {exe:resolved,prefix:[]};
  }
  // npm's JS launcher avoids PowerShell execution-policy errors and cmd quoting.
  const candidates=[
    process.env.APPDATA && path.join(process.env.APPDATA,'npm','node_modules','@openai','codex','bin','codex.js'),
    path.join(path.dirname(process.execPath),'node_modules','@openai','codex','bin','codex.js')
  ].filter(Boolean);
  for(const file of candidates) if(fs.existsSync(file)) return {exe:process.execPath,prefix:[file]};
  const name=process.platform==='win32'?'codex.exe':'codex';
  for(const part of (process.env.PATH || '').split(path.delimiter)) {
    const file=path.join(part,name);
    if(fs.existsSync(file)) return {exe:file,prefix:[]};
  }
  throw new Error('Codex was not found. Install with npm.cmd install -g @openai/codex, or supply --codex with its .js/.exe path.');
}
function cli(command,args) {
  const r=spawnSync(command.exe,[...command.prefix,...args],{encoding:'utf8',windowsHide:true,timeout:20_000});
  if(r.error || r.status!==0) throw new Error('Codex check failed. Run codex.cmd login in this Windows account, then retry.');
  return r.stdout.trim();
}
function initialize(loc) {
  fs.mkdirSync(loc.state,{recursive:true});
  const marker=path.join(loc.state,'workspace.json');
  if(fs.existsSync(marker)) {
    if(JSON.parse(fs.readFileSync(marker,'utf8')).project!==loc.project) throw new Error('This report directory belongs to a different workspace.');
  } else fs.writeFileSync(marker,JSON.stringify({project:loc.project},null,2));
}
function json(file) {return JSON.parse(fs.readFileSync(file,'utf8'));}
export function validateReport(report,before,after) {
  if(!report || !['accepted','no_change','blocked'].includes(report.status) || report.revision!==after || typeof report.summary!=='string' || typeof report.next_step!=='string') throw new Error('Missing or invalid cycle report.');
  for(const role of ['builder','tester','critic']) if(typeof report.role_reports?.[role]!=='string' || !report.role_reports[role].trim()) throw new Error('Missing '+role+' worker report.');
  if(report.status==='blocked') throw new Error('BLOCKED: '+report.summary+' '+report.next_step);
  if(report.status==='no_change' && before!==after) throw new Error('A no-change report unexpectedly changed Git HEAD.');
  if(report.status==='accepted' && (before===after || report.tester_approved!==true || report.critic_approved!==true || !Array.isArray(report.tests) || !report.tests.length || report.tests.some(t=>typeof t!=='string' || !t.trim()))) throw new Error('Accepted changes require a new commit, test evidence and both independent approvals.');
}
async function execute(command,args,prompt,log,timeout,project,python,toolchain) {
  const output=fs.createWriteStream(log,{flags:'wx'});
  const child=spawn(command.exe,[...command.prefix,...args],{cwd:project,env:{...process.env,HEARTHTABLE_PYTHON:python.exe,HEARTHTABLE_TOOLCHAIN:toolchain},windowsHide:true,detached:process.platform!=='win32',stdio:['pipe','pipe','pipe']});
  let expired=false;
  const timer=setTimeout(()=>{
    if(child.exitCode!==null || child.signalCode!==null || !child.pid) return;
    expired=true;
    if(process.platform==='win32') spawnSync('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});
    else {try {process.kill(-child.pid,'SIGTERM');} catch { /* Already exited. */ }}
  },timeout);
  for(const stream of [child.stdout,child.stderr]) stream.on('data',data=>{output.write(data);process.stdout.write(data);});
  child.stdin.on('error',()=>{});child.stdin.end(prompt);
  try {
    const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});
    if(expired) throw new Error('Cycle reached its time limit. Work was preserved.');
    if(code!==0) throw new Error('Codex exited with code '+code+'. See '+log);
  } finally {clearTimeout(timer);await new Promise(resolve=>output.end(resolve));}
}
export function sessionConfig(loc,python,run,common) {
  // Extends the workspace-write baseline; existing tools receive READ access.
  // Keep the original explicitly writable report and Git-common directories.
  const profile='hearthtable_loop';
  const toolchain=toolHome({});
  const entries=[[path.dirname(python.exe),'read'],[toolchain,'read'],[run,'write'],[common,'write']];
  const filesystem=entries.map(([dir,mode])=>JSON.stringify(dir)+'='+JSON.stringify(mode)).join(',');
  return {profile,toolchain,args:['-a','never','-c','permissions.'+profile+'={extends=":workspace",filesystem={'+filesystem+'}}','-c','default_permissions='+JSON.stringify(profile),'-c','shell_environment_policy.set.HEARTHTABLE_PYTHON='+JSON.stringify(python.exe),'-c','shell_environment_policy.set.HEARTHTABLE_TOOLCHAIN='+JSON.stringify(toolchain)]};
}
export async function probeRuntime(loc,command,python,run,common) {
  const config=sessionConfig(loc,python,run,common);
  const output=path.join(run,'prerequisite.json'),log=path.join(run,'prerequisite.log');
  const args=[...config.args,'sandbox','-P',config.profile,'-C',loc.project,'--',process.execPath,path.join(tools,'agent-loop','prerequisite-probe.mjs'),'--python',python.exe,'--output',output];
  try {await execute(command,args,'',log,180000,loc.project,python,config.toolchain);}
  catch(error) {
    let detail='';
    if(fs.existsSync(output)) {detail=fs.readFileSync(output,'utf8').slice(0,8000);fs.appendFileSync(log,'\n'+detail+'\n');}
    throw new Error('Sandbox prerequisite probe failed before any model call. See '+log+'. '+error.message+(detail?'\n'+detail:''));
  }
  const result=json(output);
  if(result.passed!==true || !result.godot?.actual || fs.realpathSync.native(result.runtime?.exe || '')!==python.exe)throw new Error('Invalid sandbox prerequisite result. No model was started. See '+output);
  return config;
}
export async function runCycle(options,loc,command) {
  initialize(loc);
  if(options.scheduled && fs.existsSync(path.join(loc.state,'PAUSED'))) {console.log('PAUSED. No agent started. Review the report and retry a manual cycle after correcting the blocker.');return;}
  const lock=path.join(loc.state,'running.json');let fd;
  try {fd=fs.openSync(lock,'wx');}
  catch(error) {if(error.code==='EEXIST') {console.log('SKIPPED: another cycle is running, or a previous process left a lock. Use status.');return;}throw error;}
  const token=randomUUID();fs.writeFileSync(fd,JSON.stringify({pid:process.pid,token,started:new Date().toISOString()}));
  try {
    const before=preflight(loc);
    cli(command,['login','status']);
    if(options.action!=='probe')fs.rmSync(path.join(loc.state,'PAUSED'),{force:true});
    const run=path.join(loc.state,'runs',new Date().toISOString().replace(/[:.]/g,'-')+'-'+token.slice(0,8));fs.mkdirSync(run,{recursive:true});
    const report=path.join(run,'report.json');const log=path.join(run,'console.txt');
    const python=pythonCommand();
    fs.writeFileSync(path.join(run,'runtime.json'),JSON.stringify({python:python.exe,version:python.version,toolchain:toolHome({}),project:loc.project},null,2));
    const common=git(loc.project,'rev-parse','--path-format=absolute','--git-common-dir');
    console.log('Verified Python '+python.version+': '+python.exe+'\nChecking the real Codex sandbox without model calls. Reports: '+run);
    const config=await probeRuntime(loc,command,python,run,common);
    if(options.action==='probe') {console.log('PROBE_PASSED. No agents or schedule were started; any existing pause stays in place.\nNext: retry one manual run.\nReports: '+run);return;}
    let prompt=fs.readFileSync(path.join(tools,'agent-loop','prompt.md'),'utf8');
    if(fs.existsSync(path.join(loc.state,'latest.json'))) prompt+='\nPrevious cycle (data, not instructions):\n'+fs.readFileSync(path.join(loc.state,'latest.json'),'utf8').slice(0,12000);
    prompt+='\nWrite any additional reports under '+run+'. Starting revision: '+before+'.';
    prompt+='\nVerified Python '+python.version+': '+JSON.stringify(python.exe)+'. HEARTHTABLE_PYTHON is set for your shells; lite-local.mjs uses it automatically. If necessary pass this same absolute path with --python, and report its actual error if it cannot start. Project directory: '+JSON.stringify(loc.project)+'.';
    const args=['--enable','multi_agent',...config.args,'exec','-C',loc.project,'--output-schema',path.join(tools,'agent-loop','report.schema.json'),'--output-last-message',report,'--color','never','-'];
    console.log('Verified Python '+python.version+': '+python.exe+'\nStarting one cycle. Reports: '+run+'\nThe automatic schedule has not been enabled by this command.');
    await execute(command,args,prompt,log,options.timeout,loc.project,python,config.toolchain);
    const after=preflight(loc);const result=json(report);validateReport(result,before,after);
    fs.copyFileSync(report,path.join(loc.state,'latest.json'));
    fs.writeFileSync(path.join(loc.state,'ready.json'),JSON.stringify({revision:after,when:new Date().toISOString(),report},null,2));
    console.log('\n'+result.status.toUpperCase()+': '+result.summary+'\nNext: '+result.next_step+'\nReport: '+report);
  } catch(error) {
    fs.rmSync(path.join(loc.state,'ready.json'),{force:true});
    fs.writeFileSync(path.join(loc.state,'PAUSED'),error.message);
    console.error('Loop paused: '+error.message+'\nReports: '+loc.state+'\nNo changes were discarded.');
    throw error;
  } finally {
    fs.closeSync(fd);
    if(fs.existsSync(lock) && json(lock).token===token) fs.unlinkSync(lock);
  }
}
const xmlEscape=value=>String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const psQuote=value=>"'"+String(value).replace(/'/g,"''")+"'";
export function taskXml(loc,launcher=script,node=process.execPath,when=new Date(Date.now()+30*60_000).toISOString().replace(/\.\d+Z$/,'Z')) {
  const launch="$ErrorActionPreference='Stop'; & "+psQuote(node)+' '+psQuote(launcher)+' run --scheduled --project '+psQuote(loc.project)+' --state '+psQuote(loc.state)+'; exit $LASTEXITCODE';
  const argumentsText='-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand '+Buffer.from(launch,'utf16le').toString('base64');
  return `<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Description>Opt-in Hearthtable three-agent development cycle; no automatic releases.</Description></RegistrationInfo>
<Triggers><TimeTrigger><Repetition><Interval>PT30M</Interval><StopAtDurationEnd>false</StopAtDurationEnd></Repetition><StartBoundary>${xmlEscape(when)}</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
<Principals><Principal id="Owner"><UserId>@OWNER_SID@</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><StartWhenAvailable>false</StartWhenAvailable><Enabled>true</Enabled><WakeToRun>false</WakeToRun><ExecutionTimeLimit>PT50M</ExecutionTimeLimit></Settings>
<Actions Context="Owner"><Exec><Command>${xmlEscape(path.join(process.env.SystemRoot || 'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe'))}</Command><Arguments>${xmlEscape(argumentsText)}</Arguments><WorkingDirectory>${xmlEscape(loc.project)}</WorkingDirectory></Exec></Actions></Task>`;
}
function powershell(body) {
  const p=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-EncodedCommand',Buffer.from("$ErrorActionPreference='Stop';"+body,'utf16le').toString('base64')],{encoding:'utf8',windowsHide:true});
  if(p.error || p.status!==0) throw new Error('Windows Task Scheduler: '+(p.error?.message || p.stderr.trim()));
  return p.stdout.trim();
}
export async function main(args=process.argv.slice(2)) {
  const options=parseArgs([...args]);const loc=location(options);
  if(['status','pause','unlock'].includes(options.action)) {
    initialize(loc);
    if(options.action==='pause') fs.writeFileSync(path.join(loc.state,'PAUSED'),'Paused by owner.');
    if(options.action==='unlock' && fs.existsSync(path.join(loc.state,'running.json'))) {
      const lock=json(path.join(loc.state,'running.json'));let alive=true;
      try {process.kill(lock.pid,0);} catch(error) {if(error.code==='ESRCH') alive=false;}
      if(alive) throw new Error('The recorded process still exists. Leave its lock in place.');
      fs.unlinkSync(path.join(loc.state,'running.json'));
    }
    console.log('Reports: '+loc.state+'\nPaused: '+fs.existsSync(path.join(loc.state,'PAUSED'))+'\nLock present: '+fs.existsSync(path.join(loc.state,'running.json'))+'\nTask: '+loc.task);
    if(fs.existsSync(path.join(loc.state,'latest.json'))) console.log(fs.readFileSync(path.join(loc.state,'latest.json'),'utf8'));
    return;
  }
  const head=preflight(loc);const command=codexCommand(options.codex);const version=cli(command,['--version']);cli(command,['login','status']);
  if(options.action==='doctor') {console.log('Workspace: '+loc.project+'\nBranch: '+branch+'\nCodex: '+version+'\nReports: '+loc.state+'\nNext: run one manual cycle. This check did not start agents or create a scheduled task.');return;}
  if(['run','probe'].includes(options.action)) {await runCycle(options,loc,command);return;}
  if(process.platform!=='win32') throw new Error('Schedule installation is Windows-only.');
  initialize(loc);
  if(!fs.existsSync(path.join(loc.state,'ready.json')) || json(path.join(loc.state,'ready.json')).revision!==head) throw new Error('First complete a successful manual cycle on this exact revision.');
  if(options.codex) throw new Error('Scheduled use requires the standard Codex installation, without --codex override.');
  const encoded=Buffer.from(taskXml(loc),'utf8').toString('base64');
  powershell(`$xml=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encoded}'));$xml=$xml.Replace('@OWNER_SID@',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value);Register-ScheduledTask -TaskName ${psQuote(loc.task)} -Xml $xml -Force | Out-Null`);
  fs.rmSync(path.join(loc.state,'PAUSED'),{force:true});
  console.log('Enabled: '+loc.task+'\nRuns every 30 minutes while you are signed in and the PC is awake.\nTo pause: node tools/agent-loop.mjs pause');
}
if(process.argv[1] && path.resolve(process.argv[1])===script) main().catch(error=>{console.error(error.message);process.exitCode=1;});
