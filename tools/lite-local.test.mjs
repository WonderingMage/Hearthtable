import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {options,checkedProject,processEnv,snapshot,outside,git} from './lite-local.mjs';

const config='[application]\nconfig/name="Hearthtable Lite"\nconfig/edition="lite"\n';
function fixture(t) {
  const base=fs.mkdtempSync(path.join(os.tmpdir(),'hearthtable-local-test-'));
  const project=path.join(base,"source & quote's");fs.mkdirSync(project);
  git(project,'init');git(project,'config','user.name','Fixture');git(project,'config','user.email','fixture@example.invalid');
  fs.writeFileSync(path.join(project,'project.godot'),config);
  fs.writeFileSync(path.join(project,'tracked.txt'),'original');git(project,'add','.');git(project,'commit','-m','fixture');
  t.after(()=>fs.rmSync(base,{recursive:true,force:true}));
  const output=path.join(base,'results');fs.mkdirSync(output);
  return {base,project,output};
}
test('the local helper has no release/install/scheduling action',()=>{
  assert.equal(options([]).action,'doctor');
  for(const action of ['publish','install','enable'])assert.throws(()=>options([action]));
  assert.throws(()=>options(['test','--suite','classic']));assert.throws(()=>options(['test','--godot']));
});
test('unexpected product identities and custom save locations fail closed',()=>{
  checkedProject(config);
  assert.throws(()=>checkedProject(config.replace('Hearthtable Lite','Hearthtable')));
  for(const key of ['use_custom_user_dir','custom_user_dir_name','project_settings_override','name.windows'])assert.throws(()=>checkedProject(config+'config/'+key+'="foreign"\n'));
});
test('only child environments change; normal Windows and XDG values survive',t=>{
  const f=fixture(t),before={...process.env},env=processEnv(path.join(f.base,'sandbox'));
  assert.deepEqual({...process.env},before);
  assert.equal(env.APPDATA,path.join(f.base,'sandbox','data'));
  assert.equal(env.LOCALAPPDATA,path.join(f.base,'sandbox','cache'));
  assert.equal(env.TEMP,env.TMP);assert.equal(env.XDG_DATA_HOME,env.APPDATA);
  for(const name of ['data','config','cache','temp'])assert.ok(fs.statSync(path.join(f.base,'sandbox',name)).isDirectory());
});
test('snapshot tests working edits and staged new files without changing their Git state',t=>{
  const f=fixture(t);
  fs.writeFileSync(path.join(f.project,'tracked.txt'),'working edit');
  fs.writeFileSync(path.join(f.project,'staged.txt'),'new code');git(f.project,'add','staged.txt');
  fs.writeFileSync(path.join(f.project,'private.pdf'),'not source');
  const before=git(f.project,'status','--porcelain'),head=git(f.project,'rev-parse','HEAD');
  const copy=snapshot(f.project,f.output);
  assert.equal(fs.readFileSync(path.join(copy,'tracked.txt'),'utf8'),'working edit');
  assert.equal(fs.readFileSync(path.join(copy,'staged.txt'),'utf8'),'new code');
  assert.ok(!fs.existsSync(path.join(copy,'private.pdf')));assert.ok(!fs.existsSync(path.join(copy,'.git')));
  assert.equal(git(f.project,'status','--porcelain'),before);assert.equal(git(f.project,'rev-parse','HEAD'),head);
  fs.writeFileSync(path.join(copy,'tracked.txt'),'test changed the copy');
  assert.equal(fs.readFileSync(path.join(f.project,'tracked.txt'),'utf8'),'working edit');
});
test('tracked overrides cannot silently enter the isolated source copy',t=>{
  const f=fixture(t);fs.writeFileSync(path.join(f.project,'override.cfg'),'[application]\nconfig/name="Foreign"');git(f.project,'add','override.cfg');
  assert.throws(()=>snapshot(f.project,f.output),/override/);
});
test('output containment resolves parent links before writing into source',t=>{
  const f=fixture(t);outside(f.project,path.join(f.base,'outside'));
  assert.throws(()=>outside(f.project,path.join(f.project,'results')),/outside/);
  const link=path.join(f.base,'junction');fs.symlinkSync(f.project,link,process.platform==='win32'?'junction':'dir');
  assert.throws(()=>outside(f.project,path.join(link,'not-created-yet')),/outside/);
  assert.ok(!fs.existsSync(path.join(f.project,'not-created-yet')));
});
test('an absent engine fails before any snapshot, Godot process or test starts',t=>{
  const f=fixture(t),output=path.join(f.base,'must-not-exist');
  const result=spawnSync(process.execPath,[fileURLToPath(new URL('./lite-local.mjs',import.meta.url)),'test','--project',f.project,'--toolchain',path.join(f.base,'no-engine'),'--output',output],{encoding:'utf8',windowsHide:true});
  assert.notEqual(result.status,0);assert.match(result.stderr,/not set up/);assert.ok(!fs.existsSync(output));
});
