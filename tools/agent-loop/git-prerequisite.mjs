// Verify actual sandbox metadata writes without touching the index, refs,
// commits or source. Each exclusive temporary file is removed by its owner.
import fs from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';

function resolveGit(project,flag) {
  const result=spawnSync('git',['-C',project,'rev-parse','--path-format=absolute',flag],{encoding:'utf8',windowsHide:true});
  if(result.error || result.status!==0)throw Error('Cannot resolve Git metadata: '+(result.error?.message || result.stderr));
  return fs.realpathSync.native(result.stdout.trim());
}
export function gitPrerequisite(project) {
  const gitdir=resolveGit(project,'--git-dir'),common=resolveGit(project,'--git-common-dir');
  const checked=[...new Set([gitdir,...['objects','refs','logs'].map(name=>path.join(common,name)).filter(dir=>fs.existsSync(dir))])];
  for(const directory of checked) {
    const file=path.join(directory,'.hearthtable-permission-probe-'+randomUUID()+'.tmp');
    let owned=false;
    try {const fd=fs.openSync(file,'wx');owned=true;fs.closeSync(fd);}
    catch(error) {throw Error('Git metadata is not writable in this sandbox: '+directory+' — '+error.message+'. No source, index, refs or commits were changed.');}
    finally {if(owned)fs.unlinkSync(file);}
  }
  return {passed:true,gitdir,common,checked};
}
