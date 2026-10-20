#!/usr/bin/env python3
"""Build and verify Linux/Windows portable exports; publish only with --publish.

Linux only: test user data is verified before loading destructive game suites.
GitHub Actions supplies its own contents:write token; no personal token is needed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '4.5.1'
ENGINE_NAME = f'Godot_v{VERSION}-stable_linux.x86_64'
BASE_URL = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable'
SUITES = ['updates', 'actions', 'smoke', 'combat_range', 'encounter', 'magic', 'rooms', 'build', 'director', 'prepared', 'pdf_import']
ERROR = re.compile(r'(?m)^(?:SCRIPT ERROR:|ERROR:|.*Parse Error:|.*FAIL )')
SUMMARY = re.compile(r'\w+ (\d+) passed, (\d+) failed')


def run(cmd, **kwargs):
    return subprocess.run(cmd, check=True, text=True, **kwargs)


def digest(path, algorithm='sha256'):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, algorithm).hexdigest()


def install(toolchain):
    toolchain.mkdir(parents=True, exist_ok=True)
    sums = urllib.request.urlopen(BASE_URL + '/SHA512-SUMS.txt', timeout=60).read().decode()
    checksums = {line.split()[1].lstrip('*'): line.split()[0] for line in sums.splitlines() if line.strip()}
    for name in [ENGINE_NAME + '.zip', f'Godot_v{VERSION}-stable_export_templates.tpz']:
        archive = toolchain / name
        if not archive.exists():
            urllib.request.urlretrieve(BASE_URL + '/' + name, archive)
        if digest(archive, 'sha512') != checksums[name]:
            raise RuntimeError(f'Official checksum verification failed: {name}')
    engine = toolchain / ENGINE_NAME
    with zipfile.ZipFile(toolchain / (ENGINE_NAME + '.zip')) as archive:
        with archive.open(ENGINE_NAME) as source, engine.open('wb') as target:
            shutil.copyfileobj(source, target)
    engine.chmod(0o755)
    templates = toolchain / 'data/godot/export_templates' / f'{VERSION}.stable'
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(toolchain / f'Godot_v{VERSION}-stable_export_templates.tpz') as archive:
        for name in ['version.txt', 'windows_release_x86_64.exe', 'windows_release_x86_64_console.exe', 'linux_release.x86_64']:
            with archive.open('templates/' + name) as source, (templates / name).open('wb') as target:
                shutil.copyfileobj(source, target)
    return engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--toolchain', type=Path)
    parser.add_argument('--publish', action='store_true')
    parser.add_argument('--repo')
    options = parser.parse_args()
    if sys.platform != 'linux':
        raise RuntimeError('This builder requires Linux; XDG variables do not isolate native Windows saves.')
    if not re.fullmatch(r'v\d+\.\d+\.\d+', options.tag):
        raise RuntimeError('Expected an existing vMAJOR.MINOR.PATCH tag')
    product = re.search(r'config/version="([^"]+)"', (ROOT / 'project.godot').read_text()).group(1)
    if options.tag != 'v' + product:
        raise RuntimeError('Tag does not match project.godot')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    tagged = subprocess.check_output(['git', 'rev-parse', options.tag + '^{commit}'], cwd=ROOT, text=True).strip()
    if commit != tagged or subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
        raise RuntimeError('Build from the clean tagged commit')
    output = options.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    tools = (options.toolchain or Path(tempfile.mkdtemp(prefix='hearthtable-godot-'))).resolve()
    engine = install(tools)
    results = {}

    def environment(label):
        base = output / 'qa' / label
        for folder in ['data', 'config', 'cache']:
            (base / folder).mkdir(parents=True)
        env = dict(os.environ, XDG_DATA_HOME=str(base / 'data'), XDG_CONFIG_HOME=str(base / 'config'), XDG_CACHE_HOME=str(base / 'cache'))
        probe = base / 'probe'
        probe.mkdir()
        (probe / 'project.godot').write_text('[application]\nconfig/name="Hearthtable"\n')
        (probe / 'probe.gd').write_text('extends SceneTree\nfunc _initialize():\n\tprint("USER_PATH="+OS.get_user_data_dir())\n\tquit()\n')
        p = run([str(engine), '--headless', '--path', str(probe), '--script', 'res://probe.gd'], env=env, capture_output=True, timeout=20)
        match = re.search(r'USER_PATH=(.+)', p.stdout)
        expected = base / 'data/godot/app_userdata/Hearthtable'
        if not match or Path(match[1].strip()).resolve() != expected.resolve() or ERROR.search(p.stdout + p.stderr):
            raise RuntimeError('Cannot prove disposable user-data isolation')
        (base / 'data/godot/export_templates').symlink_to(tools / 'data/godot/export_templates')
        return env

    def invoke(label, cmd, assertions=False):
        env = environment(label)
        with (output / 'qa' / (label + '.log')).open('w') as log:
            run(cmd, cwd=output, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        log = (output / 'qa' / (label + '.log')).read_text()
        summaries = SUMMARY.findall(log)
        if ERROR.search(log) or (assertions and (not summaries or any(int(p) == 0 or int(f) != 0 for p, f in summaries))):
            raise RuntimeError(f'{label} failed; inspect its log')
        results[label] = sum(int(p) for p, _ in summaries)
        print(f'{label}: {results[label]} assertions passed' if assertions else f'{label}: OK', flush=True)

    def command(script=None, pack=None, args=()):
        cmd = [str(engine), '--headless', '--path', str(ROOT)]
        if pack:
            cmd += ['--main-pack', str(pack)]
        if script:
            cmd += ['--script', str(ROOT / 'tests' / (script + '.gd'))]
        return cmd + list(args)

    invoke('import', command(args=['--editor', '--import']))
    portable = output / 'Hearthtable_Portable.exe'
    linux = output / 'Hearthtable_Linux.x86_64'
    invoke('export-windows', command(args=['--export-release', 'Windows Desktop', str(portable)]))
    invoke('export-linux', command(args=['--export-release', 'Linux Desktop', str(linux)]))
    update_pack=output/'Application.pck'
    invoke('export-update',command(args=['--export-pack','Windows Desktop',str(update_pack)]))
    protocol = int(re.search(r'const PROTOCOL\s*=\s*(\d+)', (ROOT / 'scripts/world.gd').read_text()).group(1))
    from make_update import build as build_update
    update_file=output/f'Hearthtable-{product}.hearthupdate'
    update_manifest=build_update(update_pack,update_file,product,commit,protocol)
    for suite in SUITES:
        invoke(suite, command(suite, portable), True)
    for label, program in [('windows', portable), ('linux', linux)]:
        copy = output / ('Synthetic_campaign_' + label)
        invoke(label + '-portable-create', command('portable', program, ['--', '--source=' + str(program), '--destination=' + str(copy)]), True)
        if label == 'windows':
            verify = command('portable', copy, ['--', '--verify', '--portable-source=' + str(copy)])
        else:
            copy.chmod(0o700)
            verify = [str(copy), '--headless', '--script', str(ROOT / 'tests/portable.gd'), '--', '--verify', '--portable-source=/not/a/campaign.exe']
        invoke(label + '-portable-restore', verify, True)
    invoke('update-cycle',[sys.executable,str(ROOT/'tools/test_updates.py'),'--engine',str(engine),'--program',str(linux),'--templates',str(tools/'data/godot/export_templates'),'--output',str(output/'qa/compiled-update-cycle')],True)
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
        raise RuntimeError('Build modified source files')
    protocol = int(re.search(r'const PROTOCOL\s*=\s*(\d+)', (ROOT / 'scripts/world.gd').read_text()).group(1))
    manifest = {'commit': commit, 'dirty': False, 'engine': VERSION, 'product': product, 'protocol': protocol, 'filename': portable.name, 'sha256': digest(portable), 'update':{'filename':update_file.name,'sha256':digest(update_file),'pack_sha256':update_manifest['sha256']},'assertions': results}
    (output / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'SHA256SUMS.txt').write_text(manifest['sha256'] + '  ' + portable.name + '\n'+digest(update_file)+'  '+update_file.name+'\n')
    notes = f'''# Hearthtable {product} — portable Windows prerelease

Download **Hearthtable_Portable.exe** and run it directly. The engine, game resources, prepared maps and notices are embedded. No ZIP, installer or Godot installation is required. The checksum and manifest are optional verification files.

This release adds an ornate fantasy interface with original painted portraits, bronze frames and expanded character information; original-2014 grapple, shove, Help and Dodge support; a shared character creator/PDF review menu; and persistent cosmetic miniatures. Campaign schema remains 1. Multiplayer protocol is {protocol}; hosts and guests must use a matching build. See the included help for supported rules and DM adjudication.

Also attached: **{update_file.name}**. Download this portable EXE once to obtain the new updater, then use **Settings → Import application update** for this and subsequent code/assets updates. The importer verifies the file against its published GitHub release, saves a campaign backup and retains rollback before restarting. A portable campaign copy embeds the active updated code and campaign together. Version 0.11.1 has no update importer and needs the new EXE first. Engine/updater-foundation changes may still require a new EXE.

Built from clean commit `{commit}` with official Godot {VERSION} and checksum-verified export templates. This automated run passed **{sum(results.values())} assertions** across {len(SUITES)} exported headless suites, Windows/Linux portable creation/restoration, and a real compiled-code install/restart/portable/rollback cycle. This automated run does not validate graphical UI or actual UDP sessions; their separate results belong in the release checklist.

Native Windows launch, GPU/audio and external internet play remain untested, so this is a prerelease. This is the plain player program; synthetic or private campaign copies are not release assets.

SHA-256: `{manifest['sha256']}`.
'''
    (output / 'RELEASE_NOTES.md').write_text(notes)
    print('Verified executable:', portable, flush=True)
    if not options.publish:
        return
    if not options.repo or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', options.repo):
        raise RuntimeError('--repo owner/name is required for publication')
    repo_args = ['--repo', options.repo]
    releases = json.loads(subprocess.check_output(['gh', 'api', f'repos/{options.repo}/releases?per_page=100'], text=True))
    existing = next((r for r in releases if r['tag_name'] == options.tag), None)
    if existing and not existing['draft']:
        raise RuntimeError('This tag is already published; never replace published assets')
    if not existing:
        run(['gh', 'release', 'create', options.tag, *repo_args, '--verify-tag', '--draft', '--prerelease', '--title', f'Hearthtable {product} — portable Windows prerelease', '--notes-file', str(output / 'RELEASE_NOTES.md')])
    else:
        allowed = {portable.name,update_file.name, 'SHA256SUMS.txt', 'build-manifest.json'}
        if any(asset['name'] not in allowed for asset in existing['assets']):
            raise RuntimeError('Draft contains unexpected assets; inspect before publication')
        run(['gh', 'release', 'edit', options.tag, *repo_args, '--target', commit, '--prerelease', '--notes-file', str(output / 'RELEASE_NOTES.md')])
    run(['gh', 'release', 'upload', options.tag, str(portable),str(update_file), str(output / 'SHA256SUMS.txt'), str(output / 'build-manifest.json'), *repo_args, '--clobber'])
    download = output / 'download-check'
    download.mkdir()
    run(['gh', 'release', 'download', options.tag, *repo_args, '--pattern', portable.name, '--dir', str(download)])
    if digest(download / portable.name) != manifest['sha256']:
        raise RuntimeError('Uploaded download failed checksum verification; leave release unpublished')
    run(['gh','release','download',options.tag,*repo_args,'--pattern',update_file.name,'--dir',str(download)])
    if digest(download/update_file.name)!=digest(update_file):raise RuntimeError('Uploaded update failed checksum verification; leave release unpublished')
    run(['gh', 'release', 'edit', options.tag, *repo_args, '--draft=false', '--prerelease'])
    run(['gh', 'release', 'view', options.tag, *repo_args, '--json', 'url,isDraft,isPrerelease'])


if __name__ == '__main__':
    main()
