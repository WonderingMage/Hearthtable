// Runs inside the real Codex sandbox without model calls or game autoloads.
import fs from 'node:fs';
import path from 'node:path';
import {pythonCommand} from '../python-runtime.mjs';
import {engine,isolated,toolHome} from '../lite-local.mjs';
import {gitPrerequisite} from './git-prerequisite.mjs';

const args=process.argv.slice(2),get=key=>args[args.indexOf(key)+1];
const python=get('--python'),output=get('--output');
if(!args.includes('--python') || !path.isAbsolute(python || '') || !args.includes('--output') || !path.isAbsolute(output || ''))throw Error('Expected absolute --python and --output paths.');
const result={passed:false,cwd:process.cwd(),python,exists:fs.existsSync(python),systemRootPresent:Boolean(process.env.SystemRoot || process.env.SYSTEMROOT),toolchain:toolHome({})};
try {
  const runtime=pythonCommand(python);
  result.runtime=runtime;
  result.git=gitPrerequisite(process.cwd());
  const tool=await engine({});
  const base=path.join(path.dirname(output),'godot-prerequisite');
  await isolated(base,tool.exe);
  result.godot={exe:tool.exe,...JSON.parse(fs.readFileSync(path.join(base,'isolation.json'),'utf8'))};
  result.passed=true;
} catch(error) {result.error=error.message;process.exitCode=1;}
fs.writeFileSync(output,JSON.stringify(result,null,2),{flag:'wx'});
console.log(JSON.stringify(result,null,2));
if(result.passed)console.log('SANDBOX_PREREQUISITES_OK: no model, game, campaign test or worker was started.');
