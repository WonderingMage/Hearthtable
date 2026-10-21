// Runs inside the real Codex sandbox without starting a model or loading Godot.
import fs from 'node:fs';
import path from 'node:path';
import {pythonCommand} from '../python-runtime.mjs';

const args=process.argv.slice(2),get=key=>args[args.indexOf(key)+1];
const python=get('--python'),output=get('--output');
if(!args.includes('--python') || !path.isAbsolute(python || '') || !args.includes('--output') || !path.isAbsolute(output || ''))throw Error('Expected absolute --python and --output paths.');
const result={passed:false,cwd:process.cwd(),python,exists:fs.existsSync(python),systemRootPresent:Boolean(process.env.SystemRoot || process.env.SYSTEMROOT)};
try {
  const runtime=pythonCommand(python);
  result.runtime=runtime;result.passed=true;
} catch(error) {result.error=error.message;process.exitCode=1;}
fs.writeFileSync(output,JSON.stringify(result,null,2),{flag:'wx'});
console.log(JSON.stringify(result,null,2));
if(result.passed)console.log('SANDBOX_PREREQUISITES_OK: no model, game, campaign test or worker was started.');
