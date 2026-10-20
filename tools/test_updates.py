#!/usr/bin/env python3
"""Exercise compiled updates/restarts/portable rebaking in isolated Linux processes."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
BAD=re.compile(r'(?m)^(?:SCRIPT ERROR:|ERROR:|.*Parse Error:|.*FAIL )')
SUMMARY=re.compile(r'UPDATE_PHASE_RESULT (\d+) passed, (\d+) failed')

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--engine',type=Path,required=True);parser.add_argument('--program',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--templates',type=Path,required=True)
    args=parser.parse_args();engine=args.engine.resolve();program=args.program.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=False)
    def environment(name):
        base=output/name
        for folder in ['data','config','cache']:(base/folder).mkdir(parents=True,exist_ok=True)
        env=dict(os.environ,XDG_DATA_HOME=str(base/'data'),XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
        probe=base/'probe';probe.mkdir(exist_ok=True);(probe/'project.godot').write_text('[application]\nconfig/name="Hearthtable Lite"\n');(probe/'probe.gd').write_text('extends SceneTree\nfunc _initialize():\n\tprint("USER_PATH="+OS.get_user_data_dir())\n\tquit()\n')
        p=subprocess.run([str(engine),'--headless','--path',str(probe),'--script','res://probe.gd'],env=env,capture_output=True,text=True,timeout=20,check=True)
        expected=(base/'data/godot/app_userdata/Hearthtable Lite').resolve();match=re.search(r'USER_PATH=(.+)',p.stdout)
        if not match or Path(match[1].strip()).resolve()!=expected or BAD.search(p.stdout+p.stderr):raise RuntimeError('Disposable user-data isolation failed')
        (base/'isolation.txt').write_text(str(expected));template_link=base/'data/godot/export_templates';template_link.parent.mkdir(parents=True,exist_ok=True)
        if not template_link.exists():template_link.symlink_to(args.templates.resolve())
        return env
    def execute(name,cmd,env,assertions=False):
        with (output/f'{name}.log').open('w') as log:subprocess.run(cmd,env=env,cwd=output,stdout=log,stderr=subprocess.STDOUT,text=True,timeout=180,check=True)
        log=(output/f'{name}.log').read_text();summary=SUMMARY.search(log)
        if BAD.search(log) or (assertions and (not summary or int(summary[1])==0 or int(summary[2])!=0)):raise RuntimeError(f'{name} failed; see its log')
        count=int(summary[1]) if summary else 0;print(f'{name}: {count} assertions' if assertions else f'{name}: OK',flush=True);return count
    fixture=output/'fixture';fixture.mkdir()
    for name in ['scripts','assets']:shutil.copytree(ROOT/name,fixture/name)
    for name in ['main.tscn','project.godot','export_presets.cfg']:shutil.copy2(ROOT/name,fixture/name)
    world=fixture/'scripts/world.gd';world.write_text(world.read_text()+'\nconst UPDATE_INTEGRATION_MARKER="COMPILED_WORLD_UPDATED"\n')
    project=fixture/'project.godot';version=re.search(r'config/version="([^"]+)"',project.read_text())[1].split('-')[0];parts=[int(p) for p in version.split('.')];parts[2]+=1;target='.'.join(str(p) for p in parts)
    project.write_text(re.sub(r'config/version="[^"]+"',f'config/version="{target}"',project.read_text()))
    build_env=environment('build');execute('import',[str(engine),'--headless','--path',str(fixture),'--editor','--import'],build_env)
    pack=output/'fixture.pck';execute('export',[str(engine),'--headless','--path',str(fixture),'--export-pack','Windows Desktop',str(pack)],build_env)
    from make_update import build
    protocol=int(re.search(r'const PROTOCOL\s*=\s*(\d+)',(ROOT/'scripts/world.gd').read_text())[1])
    package=output/'fixture.hearthupdate';build(pack,package,target,'a'*40,protocol,['Synthetic compiled-code lifecycle verification'])
    active_env=environment('campaign');portable_env=environment('transferred');copy=output/'Synthetic_updated_campaign.x86_64';script=ROOT/'tests/update_cycle.gd';total=0
    for phase in ['install','updated','portable','rollback','base']:
        if phase=='portable':copy.chmod(0o700)
        cmd=[str(copy if phase=='portable' else program),'--headless','--script',str(script),'--','--phase='+phase,'--package='+str(package),'--program='+str(program),'--copy='+str(copy),'--base='+version,'--target='+target]
        total+=execute(phase,cmd,portable_env if phase=='portable' else active_env,True)
    print(f'UPDATE_CYCLE_RESULT {total} passed, 0 failed',flush=True)

if __name__=='__main__':main()
