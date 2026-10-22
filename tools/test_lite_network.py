#!/usr/bin/env python3
"""Exercise one DM and two independent player processes with isolated Lite saves."""
import argparse,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# -I deliberately removes the script directory from sys.path. Load this local,
# tracked helper explicitly rather than depending on packages or PYTHONPATH.
import importlib.util
spec=importlib.util.spec_from_file_location('godot_log',ROOT/'tools/godot_log.py')
policy=importlib.util.module_from_spec(spec);spec.loader.exec_module(policy)
SUMMARY=re.compile(r'LITE_NETWORK_PHASE (\d+) passed, (\d+) failed')
def role_diagnostics(output,statuses):
    details=[]
    for name,status in statuses.items():
        file=output/f'{name}.log'
        if not file.exists():continue
        lines=file.read_text(errors='replace').splitlines();important=[]
        for index,line in enumerate(lines):
            if re.search(r'SCRIPT ERROR:|^ERROR:|FAIL |LITE_NETWORK_PHASE ',line):important.extend(lines[index:index+3])
        text='\n'.join(important)[:1600] if important else '\n'.join(lines[-8:])[-700:]
        code='running' if status is None else f'{status} (0x{status & 0xffffffff:08X})'
        details.append(f'{name}: {code}\n{text}')
    return '\n'.join(details)
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--engine',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--pack',type=Path);p.add_argument('--ui',action='store_true');a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(parents=True,exist_ok=False)
    processes=[];handles=[];total=0
    try:
        for name,flags in [('host',['--host']),('player',[]),('observer',['--observer'])]:
            base=a.output/name
            for part in ['data','config','cache','temp']:(base/part).mkdir(parents=True)
            env=dict(os.environ,XDG_DATA_HOME=str(base/'data'),XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
            # Godot 4.5.1 Windows uses APPDATA, not XDG_DATA_HOME. Override only
            # the child processes and prove the resulting path before World loads.
            if os.name=='nt':env.update(APPDATA=str(base/'data'),LOCALAPPDATA=str(base/'cache'),TEMP=str(base/'temp'),TMP=str(base/'temp'))
            probe=base/'probe';probe.mkdir();(probe/'project.godot').write_text('[application]\nconfig/name="Hearthtable Lite"\n');(probe/'probe.gd').write_text('extends SceneTree\nfunc _initialize():\n\tprint("USER_PATH="+OS.get_user_data_dir())\n\tquit()\n')
            r=subprocess.run([str(a.engine),'--verbose','--headless','--path',str(probe),'--script','res://probe.gd'],env=env,text=True,capture_output=True,check=True,timeout=20)
            (base/'probe.log').write_text(r.stdout+r.stderr)
            expected=(base/'data'/('Godot' if os.name=='nt' else 'godot')/'app_userdata/Hearthtable Lite').resolve();match=re.search(r'USER_PATH=(.+)',r.stdout)
            if not match or Path(match[1].strip()).resolve()!=expected or policy.godot_log(r.stdout+r.stderr)['failed']:raise RuntimeError(f'Cannot prove Lite user-data isolation; inspect {base/"probe.log"}')
            (base/'isolation.txt').write_text(str(expected))
            graphical=a.ui and name=='player';cmd=[str(a.engine),'--verbose','--audio-driver','Dummy']+([] if graphical else ['--headless'])+['--path',str(ROOT)]
            if a.pack:cmd+=['--main-pack',str(a.pack.resolve())]
            cmd+=['--script',str(ROOT/'tests/lite_network.gd'),'--']+flags+(['--ui','--qa'] if graphical else [])
            handle=(a.output/f'{name}.log').open('w');handles.append(handle);processes.append((name,subprocess.Popen(cmd,env=env,stdout=handle,stderr=subprocess.STDOUT)))
            if name=='host':
                deadline=time.monotonic()+30
                while 'PASS ' not in (a.output/'host.log').read_text():
                    if processes[-1][1].poll() is not None or time.monotonic()>deadline:raise RuntimeError('Lite host did not become ready\n'+role_diagnostics(a.output,{n:p.poll() for n,p in processes}))
                    time.sleep(.05)
        for name,process in processes:
            try:status=process.wait(timeout=240)
            except subprocess.TimeoutExpired:raise RuntimeError(f'{name} timed out\n'+role_diagnostics(a.output,{n:p.poll() for n,p in processes})) from None
            log=(a.output/f'{name}.log').read_text();summary=SUMMARY.search(log)
            assessment=policy.godot_log(log)
            if status or assessment['failed'] or not summary or int(summary[1])==0 or int(summary[2]):raise RuntimeError(f'{name} failed; inspect {a.output/name}.log\n'+role_diagnostics(a.output,{n:p.poll() for n,p in processes}))
            if assessment['builtinFallback']:print(f'{name}: verified bundled CA fallback; raw diagnostic retained in log',flush=True)
            total+=int(summary[1]);print(f'{name}: {summary[1]} assertions',flush=True)
        print(f'LITE_NETWORK_RESULT {total} passed, 0 failed',flush=True)
    finally:
        for _,process in processes:
            if process.poll() is None:process.terminate();process.wait(timeout=10)
        for handle in handles:handle.close()
if __name__=='__main__':main()
