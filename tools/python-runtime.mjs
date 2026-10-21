// Resolve a real Python interpreter before entering a restricted agent session.
// No installation, registry edits or changes to the account's environment.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const probe='import json,sys;print(json.dumps({"executable":sys.executable,"version":list(sys.version_info[:3])}))';
export function pythonCommand(explicit,env=process.env) {
  const candidates=[],failures=[];
  const configured=explicit || env.HEARTHTABLE_PYTHON;
  if(configured) {
    if(!path.isAbsolute(configured))throw Error('Configured Python must be an absolute path to python.exe (not py.exe).');
    candidates.push({exe:configured,prefix:[]});
  } else if(process.platform==='win32') {
    // python.org's per-user installation. This avoids the launcher's registry
    // lookup and WindowsApps aliases, both of which can differ inside Codex.
    if(env.LOCALAPPDATA) {
      const base=path.join(env.LOCALAPPDATA,'Programs','Python');
      try {
        if(fs.existsSync(base))for(const name of fs.readdirSync(base).filter(n=>/^Python3\d+(?:-\d+)?$/i.test(n)).sort((a,b)=>b.localeCompare(a,undefined,{numeric:true}))) {
          const exe=path.join(base,name,'python.exe');if(fs.existsSync(exe))candidates.push({exe,prefix:[]});
        }
      } catch(error) {failures.push(base+': '+error.message);}
    }
    const where=spawnSync(path.join(env.SystemRoot || 'C:\\Windows','System32','where.exe'),['python.exe'],{env,encoding:'utf8',windowsHide:true,timeout:10000});
    for(const exe of (where.stdout || '').split(/\r?\n/).filter(Boolean))if(!exe.toLowerCase().includes('windowsapps'))candidates.push({exe,prefix:[]});
    candidates.push({exe:'py.exe',prefix:['-3']});
  } else candidates.push({exe:'python3',prefix:[]});

  function check(exe,prefix=[]) {
    const result=spawnSync(exe,[...prefix,'-I','-c',probe],{env,encoding:'utf8',windowsHide:true,timeout:10000});
    if(result.error || result.status!==0)throw Error(result.error?.message || 'exit '+result.status+': '+(result.stderr || result.stdout || '').trim().slice(-1000));
    let info;try{info=JSON.parse(result.stdout.trim());}catch{throw Error('interpreter did not return the expected version/path probe');}
    if(!Array.isArray(info.version) || info.version[0]!==3 || info.version[1]<11 || !path.isAbsolute(info.executable || ''))throw Error('Python 3.11+ required; reported '+JSON.stringify(info));
    return info;
  }
  for(const candidate of candidates) {
    try {
      // On Windows the JS realpath walker lstats every ancestor. A sandbox may
      // read this installation while AppData itself remains non-enumerable.
      const detected=check(candidate.exe,candidate.prefix),exe=fs.realpathSync.native(detected.executable);
      // Always prove that the resolved interpreter runs without its launcher.
      const direct=check(exe);
      if(fs.realpathSync.native(direct.executable)!==exe)throw Error('resolved interpreter changed during verification');
      return {exe,prefix:[],version:direct.version.join('.')};
    } catch(error) {failures.push(candidate.exe+': '+error.message);}
  }
  throw Error((configured?'Configured Python could not be verified.':'Python 3.11+ could not be located or started in this session.')+
    '\n'+failures.join('\n')+'\nIf Python works in ordinary PowerShell, use its exact python.exe path with --python or HEARTHTABLE_PYTHON. Do not reinstall it solely because this check failed.');
}
