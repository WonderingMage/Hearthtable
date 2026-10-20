#!/usr/bin/env python3
"""Exercise one DM and two independent player processes with isolated Lite saves."""
import argparse,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BAD=re.compile(r'(?m)^(?:SCRIPT ERROR:|ERROR:|.*Parse Error:|.*FAIL )')
SUMMARY=re.compile(r'LITE_NETWORK_PHASE (\d+) passed, (\d+) failed')
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--engine',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--pack',type=Path);p.add_argument('--ui',action='store_true');a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(parents=True,exist_ok=False)
    processes=[];handles=[];total=0
    try:
        for name,flags in [('host',['--host']),('player',[]),('observer',['--observer'])]:
            base=a.output/name
            for part in ['data','config','cache']:(base/part).mkdir(parents=True)
            env=dict(os.environ,XDG_DATA_HOME=str(base/'data'),XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
            probe=base/'probe';probe.mkdir();(probe/'project.godot').write_text('[application]\nconfig/name="Hearthtable Lite"\n');(probe/'probe.gd').write_text('extends SceneTree\nfunc _initialize():\n\tprint("USER_PATH="+OS.get_user_data_dir())\n\tquit()\n')
            r=subprocess.run([str(a.engine),'--headless','--path',str(probe),'--script','res://probe.gd'],env=env,text=True,capture_output=True,check=True,timeout=20)
            expected=(base/'data/godot/app_userdata/Hearthtable Lite').resolve();match=re.search(r'USER_PATH=(.+)',r.stdout)
            if not match or Path(match[1].strip()).resolve()!=expected or BAD.search(r.stdout+r.stderr):raise RuntimeError('Cannot prove Lite user-data isolation')
            (base/'isolation.txt').write_text(str(expected))
            graphical=a.ui and name=='player';cmd=[str(a.engine),'--audio-driver','Dummy']+([] if graphical else ['--headless'])+['--path',str(ROOT)]
            if a.pack:cmd+=['--main-pack',str(a.pack.resolve())]
            cmd+=['--script',str(ROOT/'tests/lite_network.gd'),'--']+flags+(['--ui','--qa'] if graphical else [])
            handle=(a.output/f'{name}.log').open('w');handles.append(handle);processes.append((name,subprocess.Popen(cmd,env=env,stdout=handle,stderr=subprocess.STDOUT)))
            if name=='host':
                deadline=time.monotonic()+30
                while 'PASS ' not in (a.output/'host.log').read_text():
                    if processes[-1][1].poll() is not None or time.monotonic()>deadline:raise RuntimeError('Lite host did not become ready')
                    time.sleep(.05)
        for name,process in processes:
            status=process.wait(timeout=240);log=(a.output/f'{name}.log').read_text();summary=SUMMARY.search(log)
            if status or BAD.search(log) or not summary or int(summary[1])==0 or int(summary[2]):raise RuntimeError(f'{name} failed; inspect {a.output/name}.log')
            total+=int(summary[1]);print(f'{name}: {summary[1]} assertions',flush=True)
        print(f'LITE_NETWORK_RESULT {total} passed, 0 failed',flush=True)
    finally:
        for _,process in processes:
            if process.poll() is None:process.terminate();process.wait(timeout=10)
        for handle in handles:handle.close()
if __name__=='__main__':main()
