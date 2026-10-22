// Owner-authorized release checkpoints. Workers never receive publishing tools.
import fs from 'node:fs';
import path from 'node:path';
import {createHash,randomUUID} from 'node:crypto';
import {spawn,spawnSync} from 'node:child_process';

export const releaseEvery=5;
export const repository='WonderingMage/Hearthtable';
const sha=/^[a-f0-9]{40}$/;
const digest=/^[a-f0-9]{64}$/;
const stateFile=loc=>path.join(loc.state,'release-progress.json');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
function save(loc,state) {
  const file=stateFile(loc),temp=file+'.'+randomUUID()+'.tmp';
  try {fs.writeFileSync(temp,JSON.stringify(state,null,2)+'\n',{flag:'wx'});fs.renameSync(temp,file);}
  finally {fs.rmSync(temp,{force:true});}
}
export function releaseProgress(loc) {
  if(!fs.existsSync(stateFile(loc)))return {schema:1,pending:[],published:[],batch:null};
  const state=read(stateFile(loc));
  if(state.schema!==1 || !Array.isArray(state.pending) || !Array.isArray(state.published) || state.pending.some(x=>!sha.test(x.revision)))throw Error('Invalid release progress; preserve it for review.');
  return state;
}
export function recordAccepted(loc,result,report) {
  const state=releaseProgress(loc);
  if(result.status!=='accepted')return state;
  if(!sha.test(result.revision) || result.tester_approved!==true || result.critic_approved!==true || !result.tests?.length)throw Error('Only verified accepted improvements count toward a release.');
  if(!state.pending.some(x=>x.revision===result.revision) && !state.published.some(x=>x.improvements.includes(result.revision))) {
    state.pending.push({revision:result.revision,report});save(loc,state);
  }
  return state;
}
export function releaseStatus(loc) {
  const state=releaseProgress(loc);
  return 'Release progress: '+state.pending.length+'/'+releaseEvery+' accepted improvements'+(state.batch?' · '+state.batch.tag+' ('+state.batch.phase+')':'')+'\nPublished batches: '+state.published.length;
}
function invoke(exe,args,options={}) {
  const r=spawnSync(exe,args,{encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:32*1024*1024,...options});
  if(r.error || r.status!==0)throw Error(exe+' failed: '+(r.error?.message || r.stderr || r.stdout).trim());
  return r.stdout.trim();
}
async function validation(loc,batch) {
  const output=path.join(loc.state,'releases',batch.tag,'validation-'+randomUUID());fs.mkdirSync(output,{recursive:true});
  const helper=path.join(loc.project,'tools','lite-local.mjs');
  const deadline=Date.now()+40*60_000;
  for(const [action,extra] of [['test',['--ui']],['network',['--ui']],['build',[]]]) {
    console.log('Release '+batch.tag+': '+action+' validation. Results: '+output);
    const stream=fs.createWriteStream(path.join(output,action+'.log'),{flags:'wx'});
    const child=spawn(process.execPath,[helper,action,'--project',batch.worktree,'--output',path.join(output,action),...extra],{cwd:batch.worktree,windowsHide:true,stdio:['ignore','pipe','pipe']});
    let expired=false;
    const timer=setTimeout(()=>{if(!child.pid || child.exitCode!==null || child.signalCode!==null)return;expired=true;if(process.platform==='win32')spawnSync('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});else child.kill('SIGTERM');},Math.max(1,deadline-Date.now()));
    for(const pipe of [child.stdout,child.stderr])pipe.on('data',chunk=>{stream.write(chunk);process.stdout.write(chunk);});
    try {const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);});if(expired || code!==0)throw Error('Release '+action+' failed'+(expired?' (timeout)':'')+'; preserve '+output+'. No release tag was pushed.');}
    finally {clearTimeout(timer);await new Promise(resolve=>stream.end(resolve));}
  }
  const manifest=read(path.join(output,'build','build-manifest.json'));
  if(manifest.commit!==batch.commit || manifest.dirty!==false || manifest.version!==batch.version)throw Error('Local release validation did not build the exact clean candidate.');
  return {output,commit:batch.commit};
}
function version(value) {
  if(!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(value))throw Error('Expected a plain semantic release version.');
  const numbers=value.split('.').map(Number);if(numbers.some(x=>!Number.isSafeInteger(x)))throw Error('Version component is too large.');return numbers;
}
export function nextVersion(current,tags) {
  let selected=version(current);
  for(const tag of tags) {
    const match=/^lite-v(\d+\.\d+\.\d+)$/.exec(tag);if(!match)continue;
    const candidate=version(match[1]);
    const comparison=candidate[0]-selected[0] || candidate[1]-selected[1] || candidate[2]-selected[2];
    if(comparison>=0)selected=[candidate[0],candidate[1],candidate[2]+1];
  }
  return selected.join('.');
}
function prepare(loc,batch,git) {
  const worktree=path.join(loc.state,'releases',batch.tag,'source-'+randomUUID());
  fs.mkdirSync(path.dirname(worktree),{recursive:true});git(loc.project,'worktree','add','--detach',worktree,batch.base);
  const files=[];
  const edit=(rel,pattern,replacement,required=false)=>{
    const file=path.join(worktree,rel);if(!fs.existsSync(file)){if(required)throw Error('Missing release metadata: '+rel);return;}
    const old=fs.readFileSync(file,'utf8');if(required && !pattern.test(old))throw Error('Unexpected release metadata: '+rel);
    const updated=old.replace(pattern,replacement);if(updated!==old){fs.writeFileSync(file,updated);files.push(rel);}
  };
  edit('project.godot',/^config\/version="[^"]+"$/m,'config/version="'+batch.version+'"',true);
  edit('assets/help/lite.txt',/^HEARTHTABLE LITE \d+\.\d+\.\d+/,'HEARTHTABLE LITE '+batch.version);
  edit('AGENTS.md',/\*\*Hearthtable Lite \d+\.\d+\.\d+\*\*/,'**Hearthtable Lite '+batch.version+'**');
  edit('CODEX_HANDOFF.md',/This branch is \*\*Hearthtable Lite \d+\.\d+\.\d+ in development\*\*/,'This branch is **Hearthtable Lite '+batch.version+' in development**');
  const rel='docs/release-batches.json',file=path.join(worktree,rel);fs.mkdirSync(path.dirname(file),{recursive:true});
  const batches=fs.existsSync(file)?read(file):[];if(!Array.isArray(batches) || batches.some(x=>x.tag===batch.tag))throw Error('Release batch metadata already exists or is invalid.');
  const highlightsRel='docs/release-highlights.json',highlightsFile=path.join(worktree,highlightsRel);
  const current=fs.existsSync(highlightsFile)?read(highlightsFile):[];
  if(!Array.isArray(current) || current.some(x=>typeof x!=='string' || !x.trim() || x.length>8000))throw Error('Invalid release highlights.');
  const previous=batches.length?JSON.parse(git(worktree,'show',batches.at(-1).tag+':'+highlightsRel)):[];
  if(!Array.isArray(previous))throw Error('Invalid prior release highlights.');
  let highlights=current.filter(x=>!previous.includes(x));
  if(!highlights.length)highlights=batch.improvements.map(revision=>git(worktree,'log','-1','--format=%s',revision));
  highlights=[...new Set(highlights)];
  fs.writeFileSync(highlightsFile,JSON.stringify(highlights,null,2)+'\n');files.push(highlightsRel);
  batches.push({tag:batch.tag,version:batch.version,improvements:batch.improvements,highlights});
  fs.writeFileSync(file,JSON.stringify(batches,null,2)+'\n');files.push(rel);
  git(worktree,'add','--',...files);git(worktree,'-c','gc.auto=0','-c','maintenance.auto=false','commit','-m','Release Hearthtable Lite '+batch.version,'--only','--',...files);
  if(git(worktree,'status','--porcelain'))throw Error('Release worktree changed during metadata preparation; preserve '+worktree);
  return {worktree,commit:git(worktree,'rev-parse','HEAD')};
}
const requiredAssertions=['lite','updates','pdf_import','three-process-network','windows-portable-create','windows-portable-restore','linux-portable-create','linux-portable-restore','compiled-update-cycle'];
async function hash(file) {const h=createHash('sha256');for await(const chunk of fs.createReadStream(file))h.update(chunk);return h.digest('hex');}
function assetNames(batch,release) {
  const names=['Hearthtable-Lite-'+batch.version+'-Windows.zip','Hearthtable-Lite-'+batch.version+'.hearthupdate','SHA256SUMS.txt','build-manifest.json'];
  if(release.tag_name!==batch.tag || release.assets?.length!==names.length || names.some(name=>release.assets.filter(x=>x.name===name).length!==1))throw Error('Expected exactly the installer ZIP, matching update, checksums and manifest.');
  return names;
}
export async function verifyAssets(batch,release,folder) {
  const names=assetNames(batch,release);
  for(const name of names) {
    const asset=release.assets.find(x=>x.name===name);
    if(asset.digest!=='sha256:'+await hash(path.join(folder,name)))throw Error('Release download/GitHub digest mismatch: '+name);
  }
  const m=read(path.join(folder,'build-manifest.json'));
  if(m.validation!==false || m.dirty!==false || m.edition!=='lite' || m.tag!==batch.tag || m.version!==batch.version || m.commit!==batch.commit || m.engine!=='4.5.1' || m.installer?.native_installer_test!==true)throw Error('Release manifest does not prove the exact tested installer candidate.');
  if(requiredAssertions.some(key=>!Number.isSafeInteger(m.assertions?.[key]) || m.assertions[key]<=0))throw Error('Required release test evidence is missing.');
  if(m.installer.filename!==names[0] || m.update?.filename!==names[1] || !digest.test(m.installer.sha256) || !digest.test(m.update.sha256))throw Error('Unexpected release payload metadata.');
  const sums=fs.readFileSync(path.join(folder,'SHA256SUMS.txt'),'utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/);
  if(sums.length!==2)throw Error('Expected checksums for exactly two release payloads.');
  const parsed=new Map(sums.map(line=>{const match=/^([a-f0-9]{64})\s+([^\s]+)$/.exec(line);if(!match)throw Error('Invalid release checksum line.');return [match[2],match[1]];}));
  for(const [name,wanted] of [[names[0],m.installer.sha256],[names[1],m.update.sha256]])if(parsed.get(name)!==wanted || await hash(path.join(folder,name))!==wanted)throw Error('Release payload checksum mismatch: '+name);
  return m;
}
export async function advanceRelease(loc,adapters={}) {
  const state=releaseProgress(loc);
  if(state.pending.length<releaseEvery && !state.batch)return {due:false,message:'NO_RELEASE_DUE: '+releaseStatus(loc)};
  const call=adapters.invoke || invoke;
  const git=(project,...args)=>call('git',['-C',project,...args]);
  const api=endpoint=>JSON.parse(call('gh',['api',...endpoint]));
  try {call('gh',['auth','status']);}catch(error){throw Error('Automatic releases need GitHub CLI signed in on this PC. Install GitHub.cli, reopen PowerShell and run gh auth login. '+error.message);}
  const repo=api(['repos/'+repository]);if(repo.permissions?.push!==true)throw Error('The signed-in GitHub account needs write access to '+repository+'.');
  const head=git(loc.project,'rev-parse','HEAD');
  if(state.batch && ![state.batch.base,state.batch.commit].includes(head))throw Error('The source changed while a release checkpoint was pending. Preserve both candidates and review release-progress.json before continuing.');
  if(!state.batch) {
    for(const item of state.pending.slice(0,releaseEvery))git(loc.project,'merge-base','--is-ancestor',item.revision,head);
    const project=fs.readFileSync(path.join(loc.project,'project.godot'),'utf8');
    const current=/^config\/version="([^"]+)"$/m.exec(project)?.[1];
    const remote=git(loc.project,'ls-remote','--tags','origin','lite-v*').split(/\r?\n/).map(line=>line.split('refs/tags/')[1]?.replace(/\^\{\}$/,'' )).filter(Boolean);
    const local=git(loc.project,'tag','--list','lite-v*').split(/\r?\n/);
    const selected=nextVersion(current,[...remote,...local]);
    state.batch={base:head,version:selected,tag:'lite-v'+selected,improvements:state.pending.slice(0,releaseEvery).map(x=>x.revision),phase:'preparing'};save(loc,state);
  }
  const batch=state.batch;
  if(!batch.commit) {Object.assign(batch,prepare(loc,batch,git));save(loc,state);}
  if(!batch.validation) {
    batch.phase='validating';save(loc,state);
    const result=await (adapters.validate || validation)(loc,batch);
    if(result.commit!==batch.commit)throw Error('Release validation returned the wrong source commit.');
    batch.validation=result;batch.phase='validated';save(loc,state);
  }
  const remoteTags=git(loc.project,'ls-remote','--tags','origin','refs/tags/'+batch.tag).trim();
  if(remoteTags && remoteTags.split(/\s+/)[0]!==batch.commit)throw Error('Never replace an existing release tag: '+batch.tag);
  if(!remoteTags) {
    const existing=git(loc.project,'tag','--list',batch.tag);
    if(existing && git(loc.project,'rev-parse','refs/tags/'+batch.tag)!==batch.commit)throw Error('Local release tag points to a different candidate.');
    if(!existing)git(loc.project,'tag',batch.tag,batch.commit);
    // Credentials stay in GitHub CLI; nothing is written to global Git config.
    git(loc.project,'-c','credential.helper=','-c','credential.helper=!gh auth git-credential','push','origin','refs/tags/'+batch.tag+':refs/tags/'+batch.tag);
  }
  batch.phase='queued';batch.queued_at ||= new Date().toISOString();save(loc,state);
  const pages=api(['--paginate','--slurp','repos/'+repository+'/releases?per_page=100']);
  const releases=pages.flat();const matches=releases.filter(x=>x.tag_name===batch.tag);
  if(matches.length>1)throw Error('Multiple releases have the same tag.');
  const runs=api(['repos/'+repository+'/actions/workflows/release.yml/runs?head_sha='+batch.commit+'&per_page=100']).workflow_runs.filter(x=>x.head_sha===batch.commit).sort((a,b)=>b.id-a.id);
  const active=runs.some(x=>x.status!=='completed');const latest=runs[0];
  batch.workflow=latest?.html_url || 'https://github.com/'+repository+'/actions/workflows/release.yml';save(loc,state);
  const release=matches[0];
  if(release && (!release.draft || (latest && !active))) {
    assetNames(batch,release);
    const folder=path.join(loc.state,'releases',batch.tag,'download-'+randomUUID());fs.mkdirSync(folder,{recursive:true});
    call('gh',['release','download',batch.tag,'--repo',repository,'--dir',folder]);
    await verifyAssets(batch,release,folder);
    if(release.draft) {
      call('gh',['release','edit',batch.tag,'--repo',repository,'--draft=false','--prerelease']);
      const updated=api(['--paginate','--slurp','repos/'+repository+'/releases?per_page=100']).flat().find(x=>x.tag_name===batch.tag);
      if(!updated || updated.draft)throw Error('Verified draft retained; finish publication on the GitHub Releases website.');
      await verifyAssets(batch,updated,folder);
    }
    // Publication is verified before advancing the development checkout.
    git(loc.project,'merge','--ff-only',batch.commit);
    const receipt={tag:batch.tag,version:batch.version,commit:batch.commit,improvements:batch.improvements,url:'https://github.com/'+repository+'/releases/tag/'+batch.tag,validation:batch.validation,verified_at:new Date().toISOString()};
    state.published.push(receipt);state.pending=state.pending.slice(releaseEvery);state.batch=null;save(loc,state);
    // Remove only our clean, committed release worktree. Failed candidates and
    // validation/download evidence are retained; never force removal.
    try {if(git(batch.worktree,'rev-parse','HEAD')===batch.commit && !git(batch.worktree,'status','--porcelain'))git(loc.project,'worktree','remove',batch.worktree);}
    catch {console.log('Published release worktree retained for review: '+batch.worktree);}
    return {due:true,status:'published',revision:batch.commit,report:stateFile(loc),message:'PUBLISHED: '+receipt.url+'\n'+releaseStatus(loc)};
  }
  if(latest?.status==='completed' && latest.conclusion!=='success' && !active)throw Error('Release validation/publication failed. No successful release is claimed. Preserve the batch and inspect '+latest.html_url);
  if(Date.now()-Date.parse(batch.queued_at)>60*60_000)throw Error('Release is still unpublished after one hour. Check Actions/draft publication at '+batch.workflow);
  return {due:true,status:'queued',message:'RELEASE_PENDING: '+batch.tag+'\n'+batch.workflow+'\nNo improvement agents started. The next scheduled run checks publication.'};
}
