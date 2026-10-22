import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {options,checkedProject,processEnv,snapshot,outside,git,pythonCommand} from './lite-local.mjs';
import {godotLog} from './godot-log.mjs';

const config='[application]\nconfig/name="Hearthtable Lite"\nconfig/edition="lite"\n';
test('only the pinned Windows store diagnostic with proven builtin CA fallback is recoverable',()=>{
  const banner='Godot Engine v4.5.1.stable.official.f62fdbde1 - https://godotengine.org\n';
  const store='ERROR: Failed to read the root certificate store.\n   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2548)\n';
  const loaded='Loaded builtin CA certificates\n';
  const good=banner+store+loaded+'LITE_RESULT 94 passed, 0 failed\n';
  const cases=[
    [good,'win32',false,true], [good.replaceAll('\n','\r\n'),'win32',false,true],
    [banner+loaded,'win32',false,false],
    [good,'linux',true,false], [good.replace(loaded,''),'win32',true,false],
    [good.replace('4.5.1','4.5.2'),'win32',true,false],
    [good.replace(':2548',':2549'),'win32',true,false],
    [good.replace('get_system_ca_certificates','unrelated_function'),'win32',true,false],
    [good+store,'win32',true,false], [good+loaded,'win32',true,false],
    [good+'ERROR: Certificate parsing failed.\n','win32',true,true],
    [good+'SCRIPT ERROR: Broken spell description\n','win32',true,true],
    [good+'Parse Error: Invalid code\n','win32',true,true],
    [good+'FAIL authority check\n','win32',true,true],
    [good+'ERROR: Unable to send packet on channel 0, max channels: 0\n','win32',true,true],
    [store,'win32',true,false]
  ];
  const expected=cases.map(([, ,failed,builtinFallback])=>({failed,builtinFallback}));
  assert.deepEqual(cases.map(([log,platform])=>godotLog(log,platform)),expected);
  // The -I Python network runner must make exactly the same decisions.
  const py=pythonCommand(),module=fileURLToPath(new URL('./godot_log.py',import.meta.url));
  const code='import importlib.util,json,sys;s=importlib.util.spec_from_file_location("policy",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);print(json.dumps([m.godot_log(log,platform) for log,platform,*_ in json.load(sys.stdin)]))';
  const result=spawnSync(py.exe,['-I','-c',code,module],{encoding:'utf8',input:JSON.stringify(cases),windowsHide:true});
  assert.equal(result.status,0,result.stderr);assert.deepEqual(JSON.parse(result.stdout),expected);
});
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
test('a multiplayer failure retains every role error and the native exit code',()=>{
  const py=pythonCommand(),module=fileURLToPath(new URL('./test_lite_network.py',import.meta.url));
  const code='import importlib.util,pathlib,sys,tempfile;s=importlib.util.spec_from_file_location("network",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)\nwith tempfile.TemporaryDirectory() as folder:\n p=pathlib.Path(folder);(p/"host.log").write_text("FAIL Timeout waiting for player\\n");(p/"player.log").write_text("SCRIPT ERROR: Synthetic peer failure\\n at: sample.gd:4\\n"+"verbose cleanup\\n"*100);(p/"observer.log").write_text("Waiting for DM decision\\n");print(m.role_diagnostics(p,{"host":1,"player":3221225477,"observer":None}))';
  const result=spawnSync(py.exe,['-I','-c',code,module],{encoding:'utf8',windowsHide:true});
  assert.equal(result.status,0,result.stderr);assert.match(result.stdout,/Timeout waiting for player/);assert.match(result.stdout,/Synthetic peer failure/);assert.match(result.stdout,/sample.gd:4/);assert.match(result.stdout,/0xC0000005/);assert.match(result.stdout,/observer: running/);
});
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
test('the resolved Python works directly when PATH and launcher discovery are unavailable',()=>{
  const runtime=pythonCommand(),env={...process.env,PATH:'',HEARTHTABLE_PYTHON:runtime.exe};
  assert.ok(path.isAbsolute(runtime.exe));assert.deepEqual(runtime.prefix,[]);
  const direct=pythonCommand(undefined,env);
  assert.equal(direct.exe,runtime.exe);assert.equal(direct.version,runtime.version);
  assert.deepEqual(pythonCommand(runtime.exe,{...env,HEARTHTABLE_PYTHON:'invalid'}),direct);
});
test('a broken configured interpreter reports its actual error without silently falling back',()=>{
  const before={...process.env};
  assert.throws(()=>pythonCommand(undefined,{...process.env,HEARTHTABLE_PYTHON:process.execPath}),error=>{
    assert.match(error.message,/Configured Python could not be verified/);
    assert.ok(error.message.includes(process.execPath));assert.match(error.message,/exit \d+/);return true;
  });
  assert.throws(()=>pythonCommand('relative-python.exe'),/absolute path/);
  assert.deepEqual({...process.env},before);
});
test('Windows per-user Python is found without PATH or the registry-based launcher',{skip:process.platform!=='win32'},t=>{
  const f=fixture(t),runtime=pythonCommand();
  const appdata=path.join(f.base,"Python tools & quote's");
  const base=path.join(appdata,'Programs','Python');fs.mkdirSync(base,{recursive:true});
  fs.symlinkSync(path.dirname(runtime.exe),path.join(base,'Python313'),'junction');
  const discovered=pythonCommand(undefined,{...process.env,LOCALAPPDATA:appdata,PATH:'',HEARTHTABLE_PYTHON:''});
  assert.equal(discovered.exe,runtime.exe);assert.deepEqual(discovered.prefix,[]);
});
