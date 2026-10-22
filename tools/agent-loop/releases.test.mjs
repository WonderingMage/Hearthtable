// All GitHub/validation operations are TEST DOUBLES. Never publishes a release.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {advanceRelease,nextVersion,recordAccepted,releaseProgress,verifyAssets} from './releases.mjs';

const sum=data=>createHash('sha256').update(data).digest('hex');
function fixture(t,count=5,fullSource=false) {
  const base=fs.mkdtempSync(path.join(os.tmpdir(),'hearthtable-release-test-'));
  t.after(()=>fs.rmSync(base,{recursive:true,force:true}));
  const project=path.join(base,'source'),state=path.join(base,'state');fs.mkdirSync(project);fs.mkdirSync(state);
  const git=(...args)=>{
    const r=spawnSync('git',['-C',project,...args],{encoding:'utf8',windowsHide:true});assert.equal(r.status,0,r.stderr);return r.stdout.trim();
  };
  git('init','--initial-branch=automation/lite-improvements');git('config','user.name','Release fixture');git('config','user.email','fixture@example.invalid');
  if(fullSource) {
    const source=path.resolve(import.meta.dirname,'../..');
    const list=spawnSync('git',['-C',source,'ls-files','-z'],{encoding:'utf8',windowsHide:true});assert.equal(list.status,0,list.stderr);
    for(const rel of list.stdout.split('\0').filter(Boolean)) {const file=path.join(source,rel);if(!fs.existsSync(file))continue;const target=path.join(project,rel);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);}
  } else fs.writeFileSync(path.join(project,'project.godot'),'[application]\nconfig/name="Hearthtable Lite"\nconfig/edition="lite"\nconfig/version="1.0.2"\n');
  git('add','.');git('commit','-m','Synthetic baseline');
  const loc={project,state},revisions=[];
  const add=()=>{
    fs.writeFileSync(path.join(project,'improvement.txt'),String(revisions.length));git('add','.');git('commit','-m','Synthetic accepted improvement');
    const revision=git('rev-parse','HEAD');revisions.push(revision);
    recordAccepted(loc,{status:'accepted',revision,tester_approved:true,critic_approved:true,tests:['TEST DOUBLE']},path.join(state,'synthetic-report.json'));return revision;
  };
  for(let i=0;i<count;i++)add();
  const remote={tags:new Map(),release:null,runs:[],bytes:new Map(),calls:[],validations:0,pushes:0,edits:0};
  const adapters={
    invoke(exe,args) {
      remote.calls.push([exe,...args]);
      if(exe==='git') {
        if(args.includes('ls-remote')) {
          const pattern=args.at(-1);return [...remote.tags].filter(([tag])=>pattern==='lite-v*' || pattern==='refs/tags/'+tag).map(([tag,commit])=>commit+'\trefs/tags/'+tag).join('\n');
        }
        if(args.includes('push')) {const tag=args.at(-1).split(':')[0].replace('refs/tags/','');remote.tags.set(tag,git('rev-parse','refs/tags/'+tag));remote.pushes++;return '';}
        const r=spawnSync(exe,args,{encoding:'utf8',windowsHide:true});if(r.status!==0)throw Error(r.stderr);return r.stdout.trim();
      }
      assert.equal(exe,'gh','Unexpected external command in a release test');
      if(args[0]==='auth')return 'TEST DOUBLE: authenticated';
      if(args[0]==='api') {
        const endpoint=args.at(-1);
        if(endpoint==='repos/WonderingMage/Hearthtable')return JSON.stringify({permissions:{push:true}});
        if(endpoint.endsWith('/releases?per_page=100'))return JSON.stringify([remote.release?[remote.release]:[]]);
        if(endpoint.includes('/actions/workflows/'))return JSON.stringify({workflow_runs:remote.runs});
      }
      if(args[0]==='release' && args[1]==='download') {const folder=args[args.indexOf('--dir')+1];for(const [name,bytes] of remote.bytes)fs.writeFileSync(path.join(folder,name),bytes);return '';}
      if(args[0]==='release' && args[1]==='edit') {remote.edits++;remote.release.draft=false;return '';}
      throw Error('Unexpected GitHub operation in a release TEST DOUBLE: '+JSON.stringify(args));
    },
    async validate(loc,batch) {remote.validations++;return {commit:batch.commit,output:'SYNTHETIC TEST DOUBLE; no app or installer started'};}
  };
  function assets(draft=false) {
    const batch=releaseProgress(loc).batch;
    const zip='Hearthtable-Lite-'+batch.version+'-Windows.zip',update='Hearthtable-Lite-'+batch.version+'.hearthupdate';
    remote.bytes=new Map([[zip,Buffer.from('Synthetic installer bytes; not executable')],[update,Buffer.from('Synthetic update bytes; not an update')]]);
    const assertions=Object.fromEntries(['lite','updates','pdf_import','three-process-network','windows-portable-create','windows-portable-restore','linux-portable-create','linux-portable-restore','compiled-update-cycle'].map(x=>[x,1]));
    const manifest={validation:false,dirty:false,edition:'lite',engine:'4.5.1',tag:batch.tag,version:batch.version,commit:batch.commit,assertions,installer:{filename:zip,sha256:sum(remote.bytes.get(zip)),native_installer_test:true},update:{filename:update,sha256:sum(remote.bytes.get(update))}};
    remote.bytes.set('build-manifest.json',Buffer.from(JSON.stringify(manifest)));
    remote.bytes.set('SHA256SUMS.txt',Buffer.from(manifest.installer.sha256+'  '+zip+'\n'+manifest.update.sha256+'  '+update+'\n'));
    remote.release={tag_name:batch.tag,draft,assets:[...remote.bytes].map(([name,bytes])=>({name,digest:'sha256:'+sum(bytes)}))};return batch;
  }
  return {loc,git,add,remote,adapters,assets,revisions};
}
test('next release uses the current unused version or advances beyond existing Lite tags',()=>{
  assert.equal(nextVersion('1.0.2',['lite-v1.0.1','v9.9.9']),'1.0.2');
  assert.equal(nextVersion('1.0.2',['lite-v1.0.8','lite-v1.0.2','lite-v1.0.7']),'1.0.9');
  assert.equal(nextVersion('1.0.2',['lite-v2.0.0']),'2.0.1');assert.throws(()=>nextVersion('1.0.2-beta',[]));
});
test('only unique accepted improvements count; no-change/blocked reports do not count',t=>{
  const f=fixture(t,1),revision=f.revisions[0];
  recordAccepted(f.loc,{status:'accepted',revision,tester_approved:true,critic_approved:true,tests:['TEST DOUBLE']},'same report');
  for(const status of ['no_change','blocked'])recordAccepted(f.loc,{status,revision},'ignored');
  assert.equal(releaseProgress(f.loc).pending.length,1);
  assert.throws(()=>recordAccepted(f.loc,{status:'accepted',revision},'unapproved'));
});
test('four improvements make no network, version, tag or validation changes',async t=>{
  const f=fixture(t,4),head=f.git('rev-parse','HEAD');
  const result=await advanceRelease(f.loc,{invoke(){throw Error('No external call expected');}});
  assert.equal(result.due,false);assert.equal(f.git('rev-parse','HEAD'),head);assert.equal(f.git('tag','--list'),'');
});
test('missing release authentication preserves all five improvements before metadata edits',async t=>{
  const f=fixture(t),head=f.git('rev-parse','HEAD');
  await assert.rejects(advanceRelease(f.loc,{invoke(){throw Error('Synthetic missing gh');}}),/gh auth login/);
  assert.equal(releaseProgress(f.loc).pending.length,5);assert.equal(releaseProgress(f.loc).batch,null);assert.equal(f.git('rev-parse','HEAD'),head);
});
test('release validation failure keeps source and counter intact and never pushes a tag',async t=>{
  const f=fixture(t),head=f.git('rev-parse','HEAD');
  const failed={...f.adapters,validate:async()=>{throw Error('Synthetic Godot crash');}};
  await assert.rejects(advanceRelease(f.loc,failed),/Godot crash/);
  assert.equal(f.remote.pushes,0);assert.equal(f.git('tag','--list'),'');assert.equal(f.git('status','--porcelain'),'');assert.equal(f.git('rev-parse','HEAD'),head);
  const prepared=releaseProgress(f.loc).batch;assert.ok(prepared.commit);assert.ok(fs.existsSync(prepared.worktree));
  await advanceRelease(f.loc,f.adapters);assert.equal(releaseProgress(f.loc).batch.commit,prepared.commit);assert.equal(f.remote.pushes,1);
});
test('queued publication is idempotent and does not reset the counter or advance source',async t=>{
  const f=fixture(t),head=f.git('rev-parse','HEAD');
  assert.equal((await advanceRelease(f.loc,f.adapters)).status,'queued');
  assert.equal((await advanceRelease(f.loc,f.adapters)).status,'queued');
  assert.equal(f.remote.validations,1);assert.equal(f.remote.pushes,1);assert.equal(releaseProgress(f.loc).pending.length,5);assert.equal(f.git('rev-parse','HEAD'),head);
});
test('failed remote validation pauses publication without losing the batch',async t=>{
  const f=fixture(t);await advanceRelease(f.loc,f.adapters);const batch=releaseProgress(f.loc).batch;
  f.remote.runs=[{id:1,head_sha:batch.commit,status:'completed',conclusion:'failure',html_url:'https://example.invalid/failed-test'}];
  await assert.rejects(advanceRelease(f.loc,f.adapters),/Release validation\/publication failed/);
  assert.equal(releaseProgress(f.loc).pending.length,5);assert.equal(releaseProgress(f.loc).published.length,0);
});
test('verified published assets advance source and reset exactly five improvements',async t=>{
  const f=fixture(t),head=f.git('rev-parse','HEAD');await advanceRelease(f.loc,f.adapters);const batch=f.assets();
  const result=await advanceRelease(f.loc,f.adapters);assert.equal(result.status,'published');assert.equal(f.git('rev-parse','HEAD'),batch.commit);assert.notEqual(batch.commit,head);
  assert.equal(f.git('status','--porcelain'),'');assert.equal(releaseProgress(f.loc).pending.length,0);assert.equal(releaseProgress(f.loc).published.length,1);
  f.add();assert.equal(releaseProgress(f.loc).pending.length,1);
  await advanceRelease(f.loc,f.adapters);assert.equal(f.remote.pushes,1,'No duplicate release for fewer than five new improvements');
});
test('the next five improvements produce a new patch version and only new highlights',async t=>{
  const f=fixture(t);await advanceRelease(f.loc,f.adapters);f.assets();await advanceRelease(f.loc,f.adapters);
  const file=path.join(f.loc.project,'docs','release-highlights.json');
  for(let i=0;i<5;i++){const highlights=JSON.parse(fs.readFileSync(file,'utf8'));highlights.unshift('New campaign improvement '+i);fs.writeFileSync(file,JSON.stringify(highlights));f.add();}
  await advanceRelease(f.loc,f.adapters);const batch=releaseProgress(f.loc).batch;
  assert.equal(batch.version,'1.0.3');assert.equal(f.remote.pushes,2);assert.equal(releaseProgress(f.loc).pending.length,5);
  const highlights=JSON.parse(fs.readFileSync(path.join(batch.worktree,'docs','release-highlights.json'),'utf8'));
  assert.equal(highlights.length,5);assert.ok(highlights.every(x=>x.startsWith('New campaign improvement ')));
  assert.equal(JSON.parse(fs.readFileSync(path.join(batch.worktree,'docs','release-batches.json'),'utf8')).length,2);
});
test('a completed verified draft can publish with owner credentials; an active draft waits',async t=>{
  const f=fixture(t);await advanceRelease(f.loc,f.adapters);const batch=f.assets(true);
  f.remote.runs=[{id:1,head_sha:batch.commit,status:'in_progress',html_url:'https://example.invalid/active'}];
  assert.equal((await advanceRelease(f.loc,f.adapters)).status,'queued');assert.equal(f.remote.edits,0);
  f.remote.runs[0].status='completed';f.remote.runs[0].conclusion='failure';
  assert.equal((await advanceRelease(f.loc,f.adapters)).status,'published');assert.equal(f.remote.edits,1);
});
test('tampered assets, missing installer validation and wrong source never produce a receipt',async t=>{
  const f=fixture(t),head=f.git('rev-parse','HEAD');await advanceRelease(f.loc,f.adapters);const batch=f.assets();
  const folder=path.join(f.loc.state,'checks');fs.mkdirSync(folder);
  for(const [name,bytes] of f.remote.bytes)fs.writeFileSync(path.join(folder,name),bytes);
  const manifestFile=path.join(folder,'build-manifest.json'),original=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
  for(const changed of [{...original,commit:'f'.repeat(40)},{...original,installer:{...original.installer,native_installer_test:false}},{...original,assertions:{}}]) {
    fs.writeFileSync(manifestFile,JSON.stringify(changed));const release=structuredClone(f.remote.release);release.assets.find(x=>x.name==='build-manifest.json').digest='sha256:'+sum(fs.readFileSync(manifestFile));
    await assert.rejects(verifyAssets(batch,release,folder));
  }
  f.remote.release.assets.push({name:'unexpected-file',digest:'sha256:'+'0'.repeat(64)});
  const downloads=f.remote.calls.filter(call=>call[0]==='gh' && call[1]==='release' && call[2]==='download').length;
  await assert.rejects(advanceRelease(f.loc,f.adapters),/Expected exactly/);
  assert.equal(f.remote.calls.filter(call=>call[0]==='gh' && call[1]==='release' && call[2]==='download').length,downloads);
  f.remote.release.assets.pop();
  f.remote.bytes.set('Hearthtable-Lite-1.0.2-Windows.zip',Buffer.from('tampered'));
  await assert.rejects(advanceRelease(f.loc,f.adapters),/digest mismatch/);
  assert.equal(f.git('rev-parse','HEAD'),head);assert.equal(releaseProgress(f.loc).pending.length,5);assert.equal(releaseProgress(f.loc).published.length,0);
});
test('existing tags and independently changed development source are never overwritten',async t=>{
  const f=fixture(t);await advanceRelease(f.loc,f.adapters);const batch=releaseProgress(f.loc).batch;
  f.remote.tags.set(batch.tag,'f'.repeat(40));await assert.rejects(advanceRelease(f.loc,f.adapters),/Never replace/);assert.equal(f.remote.pushes,1);
  f.remote.tags.set(batch.tag,batch.commit);f.add();const head=f.git('rev-parse','HEAD');
  await assert.rejects(advanceRelease(f.loc,f.adapters),/source changed/);assert.equal(f.git('rev-parse','HEAD'),head);assert.equal(releaseProgress(f.loc).pending.length,6);
});
test('native release checkpoint validates real versioned app artifacts without GitHub publication',{skip:process.platform!=='win32' || process.env.HEARTHTABLE_RELEASE_VALIDATION!=='1',timeout:1200000},async t=>{
  const f=fixture(t,5,true),head=f.git('rev-parse','HEAD');
  const current=/config\/version="([^"]+)"/.exec(fs.readFileSync(path.join(f.loc.project,'project.godot'),'utf8'))[1];
  f.remote.tags.set('lite-v'+current,'f'.repeat(40));
  const result=await advanceRelease(f.loc,{invoke:f.adapters.invoke});
  assert.equal(result.status,'queued');const batch=releaseProgress(f.loc).batch;
  assert.equal(batch.version,nextVersion(current,['lite-v'+current]));assert.equal(f.git('rev-parse','HEAD'),head);assert.equal(f.git('status','--porcelain'),'');
  const build=JSON.parse(fs.readFileSync(path.join(batch.validation.output,'build','build-manifest.json'),'utf8'));
  assert.equal(build.commit,batch.commit);assert.equal(build.version,batch.version);assert.equal(build.dirty,false);
  assert.ok(build.assertions['lite-compiled']>0);assert.equal(releaseProgress(f.loc).published.length,0);
  assert.equal(f.remote.pushes,1,'TEST DOUBLE push only; GitHub never receives this synthetic source');
});
