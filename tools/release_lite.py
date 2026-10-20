#!/usr/bin/env python3
"""Build/test a clean Lite tag; publish its single Windows EXE only on --publish."""
import argparse,json,os,re,subprocess,sys,tempfile
from pathlib import Path
from release import install,digest,ERROR
from make_update import build
ROOT=Path(__file__).resolve().parents[1]
SUMMARY=re.compile(r'\w+ (\d+) passed, (\d+) failed')
SUITES=['lite','updates','pdf_import']
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--tag',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--toolchain',type=Path);p.add_argument('--publish',action='store_true');p.add_argument('--repo');a=p.parse_args()
    if sys.platform!='linux':raise RuntimeError('Linux builder only: XDG isolation does not protect native Windows saves.')
    if not re.fullmatch(r'lite-v\d+\.\d+\.\d+',a.tag):raise RuntimeError('Expected a unique lite-vMAJOR.MINOR.PATCH tag')
    project=(ROOT/'project.godot').read_text();version=re.search(r'config/version="([^"]+)"',project)[1]
    if a.tag!='lite-v'+version or 'config/edition="lite"' not in project or 'config/name="Hearthtable Lite"' not in project:raise RuntimeError('Tag and Lite product identity must match the project')
    def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    commit=git('rev-parse','HEAD')
    if commit!=git('rev-parse',a.tag+'^{commit}') or git('status','--porcelain'):raise RuntimeError('Build from the exact clean tagged source')
    output=a.output.resolve();output.mkdir(parents=True,exist_ok=False);toolchain=(a.toolchain or Path(tempfile.mkdtemp(prefix='hearthtable-lite-godot-'))).resolve();engine=install(toolchain);results={}
    def environment(label):
        base=output/'qa'/label
        for part in ['data','config','cache']:(base/part).mkdir(parents=True)
        env=dict(os.environ,XDG_DATA_HOME=str(base/'data'),XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
        probe=base/'probe';probe.mkdir();(probe/'project.godot').write_text('[application]\nconfig/name="Hearthtable Lite"\n');(probe/'probe.gd').write_text('extends SceneTree\nfunc _initialize():\n\tprint("USER_PATH="+OS.get_user_data_dir())\n\tquit()\n')
        r=subprocess.run([str(engine),'--headless','--path',str(probe),'--script','res://probe.gd'],env=env,text=True,capture_output=True,check=True,timeout=20);match=re.search(r'USER_PATH=(.+)',r.stdout);expected=(base/'data/godot/app_userdata/Hearthtable Lite').resolve()
        if not match or Path(match[1].strip()).resolve()!=expected or ERROR.search(r.stdout+r.stderr):raise RuntimeError('Cannot prove disposable Lite user-data isolation')
        (base/'isolation.txt').write_text(str(expected));(base/'data/godot/export_templates').symlink_to(toolchain/'data/godot/export_templates');return env
    def invoke(label,cmd,assertions=False):
        env=environment(label);log=output/'qa'/f'{label}.log'
        with log.open('w') as handle:subprocess.run(cmd,cwd=output,env=env,stdout=handle,stderr=subprocess.STDOUT,text=True,check=True,timeout=360)
        text=log.read_text();summaries=SUMMARY.findall(text)
        if ERROR.search(text) or (assertions and (not summaries or any(int(n)==0 or int(f)!=0 for n,f in summaries))):raise RuntimeError(f'{label} failed; inspect {log}')
        results[label]=sum(int(n) for n,_ in summaries);print(f'{label}: {results[label]} assertions passed' if assertions else f'{label}: OK',flush=True)
    def command(script=None,pack=None,args=()):
        cmd=[str(engine),'--headless','--path',str(ROOT)]
        if pack:cmd+=['--main-pack',str(pack)]
        if script:cmd+=['--script',str(ROOT/'tests'/f'{script}.gd')]
        return cmd+list(args)
    invoke('import',command(args=['--editor','--import']))
    windows=output/'Hearthtable_Lite_Portable.exe';linux=output/'Hearthtable_Lite_Linux.x86_64';pack=output/'Lite_Application.pck'
    invoke('export-windows',command(args=['--export-release','Windows Desktop',str(windows)]));invoke('export-linux',command(args=['--export-release','Linux Desktop',str(linux)]));invoke('export-update',command(args=['--export-pack','Windows Desktop',str(pack)]))
    protocol=int(re.search(r'const PROTOCOL\s*=\s*(\d+)',(ROOT/'scripts/world.gd').read_text())[1]);update=output/f'Hearthtable-Lite-{version}.hearthupdate';update_manifest=build(pack,update,version,commit,protocol)
    for suite in SUITES:invoke(suite,command(suite,windows),True)
    invoke('three-process-network',[sys.executable,str(ROOT/'tools/test_lite_network.py'),'--engine',str(engine),'--pack',str(windows),'--output',str(output/'qa/network-processes')],True)
    for label,program in [('windows',windows),('linux',linux)]:
        copy=output/f'Synthetic_Lite_{label}.exe';invoke(label+'-portable-create',command('lite_portable',program,['--','--source='+str(program),'--destination='+str(copy)]),True)
        if label=='windows':verify=command('lite_portable',copy,['--','--verify','--portable-source='+str(copy)])
        else:copy.chmod(0o700);verify=[str(copy),'--headless','--script',str(ROOT/'tests/lite_portable.gd'),'--','--verify','--portable-source=/not/a/real/campaign.exe']
        invoke(label+'-portable-restore',verify,True)
    invoke('compiled-update-cycle',[sys.executable,str(ROOT/'tools/test_updates.py'),'--engine',str(engine),'--program',str(linux),'--templates',str(toolchain/'data/godot/export_templates'),'--output',str(output/'qa/compiled-update')],True)
    if git('status','--porcelain'):raise RuntimeError('The build changed tracked/untracked source; commit missing resources before release')
    manifest={'edition':'lite','product':'Hearthtable Lite','version':version,'tag':a.tag,'commit':commit,'dirty':False,'engine':'4.5.1','protocol':protocol,'filename':windows.name,'sha256':digest(windows),'update':{'filename':update.name,'sha256':digest(update),'pack_sha256':update_manifest['sha256']},'assertions':results}
    (output/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(output/'SHA256SUMS.txt').write_text(digest(windows)+'  '+windows.name+'\n'+digest(update)+'  '+update.name+'\n')
    notes=f'''# Hearthtable Lite {version} — DM-led virtual tabletop

Download **{windows.name}** and run it directly. This is one Windows executable with the engine, resources, maps and notices embedded. No installer, ZIP or Godot installation is required. This separate Lite edition uses its own saves and protocol {protocol}; keep classic Hearthtable and its campaigns available separately.

* Rotatable isometric VTT for both roles. The DM freely places pieces, with live distance measurement, edits enemy AC/HP/abilities, imports data-only custom creatures and controls individual objects. Players move their own pawns without a distance cap outside combat; DM-started combat enforces their turn and cumulative allowance. Only the DM controls doors.
* Expandable player sheet over the board: abilities, saves, all 18 skills, passive senses, health/defenses, Hit Dice/death saves, attacks/actions/reactions, spells/slots/preparation/full references, equipment/coins/attunement, features, description, notes and extras. Filled character PDFs use the reviewed creator and customizable miniature flow.
* Private DM dice, whole-board blackout, manual fog, concealed objects/creatures and a DM-owned initiative order. Hidden records and enemy health/AC/initiative are withheld from player snapshots; fogged map pixels/geometry are removed before transfer.
* Players send rolls and intentions. Fireball and other spell proposals show 2014 rule text, damage dice, save/DC, range, area, components and duration. The DM explicitly chooses hit/save outcomes, targets, full/half damage or healing, conditions, amounts and resource spending. Attacks, spells, saves and encounters do not resolve automatically; player movement budgets are enforced only during DM-started combat.

Includes 2014 SRD 5.1 references and editable homebrew notes/custom spells. It is an independent sheet, without D&D Beyond accounts, paid-book content, its full character progression engine or a complete class/feat database. See Guide for coverage and manual adjudication.

For future compatible Lite updates, import **{update.name}** through **Settings → Import application update**. The importer verifies this repository's published Lite release digest, backs up the campaign, retains rollback and restarts. Classic Hearthtable update files are not interchangeable; download the Lite EXE once to establish this foundation. Portable DM campaign copies embed active updates and private campaign data; keep those copies private.

Built from clean commit `{commit}` with official checksum-verified Godot 4.5.1. This run passed **{sum(results.values())} assertions**, including exported Windows resources, a real DM/two-player UDP session, Windows/Linux portable campaign creation/restoration, and compiled-code installation/restart/portable transfer/rollback. Separate graphical checks are recorded below when performed.

Native Windows launch, hardware GPU/audio and external residential internet play remain untested; this is a prerelease. Only the plain player program and official update are attached, alongside optional checksums and the build manifest. QA campaigns and logs are not player assets.

EXE SHA-256: `{digest(windows)}`.
'''
    (output/'RELEASE_NOTES.md').write_text(notes);print('Verified Lite artifacts:',windows,update,flush=True)
    if not a.publish:return
    if not a.repo or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',a.repo):raise RuntimeError('--repo owner/name is required')
    def gh(*args):subprocess.run(['gh',*args,'--repo',a.repo],check=True,text=True)
    releases=json.loads(subprocess.check_output(['gh','api',f'repos/{a.repo}/releases?per_page=100'],text=True));existing=next((r for r in releases if r['tag_name']==a.tag),None);allowed={windows.name,update.name,'SHA256SUMS.txt','build-manifest.json'}
    if existing and not existing['draft']:raise RuntimeError('Never overwrite a published release')
    if existing and any(asset['name'] not in allowed for asset in existing['assets']):raise RuntimeError('Unexpected draft assets; inspect before continuing')
    if existing:gh('release','edit',a.tag,'--target',commit,'--prerelease','--notes-file',str(output/'RELEASE_NOTES.md'))
    else:gh('release','create',a.tag,'--verify-tag','--draft','--prerelease','--title',f'Hearthtable Lite {version} — DM-led VTT prerelease','--notes-file',str(output/'RELEASE_NOTES.md'))
    gh('release','upload',a.tag,*[str(output/name) for name in sorted(allowed)],'--clobber')
    download=output/'download-check';download.mkdir();gh('release','download',a.tag,'--dir',str(download))
    for name in allowed:
        if digest(download/name)!=digest(output/name):raise RuntimeError('Downloaded release asset checksum mismatch; leave draft unpublished')
    remote=json.loads(subprocess.check_output(['gh','api',f'repos/{a.repo}/releases/tags/{a.tag}'],text=True))
    for asset in remote['assets']:
        if asset['name'] in allowed and asset.get('digest')!='sha256:'+digest(output/asset['name']):raise RuntimeError('GitHub digest unavailable or incorrect; leave draft unpublished')
    gh('release','edit',a.tag,'--draft=false','--prerelease');gh('release','view',a.tag,'--json','url,isDraft,isPrerelease')
if __name__=='__main__':main()
