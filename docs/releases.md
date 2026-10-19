# Releases

Publish to `WonderingMage/Hearthtable` only when the user requests a release. A coding request by itself does not trigger publication. The next requested release includes the intended fixes since the previous release, receives a new version/tag, and leaves older releases available. Never overwrite a published tag or asset. Preserve the repository's visibility; establish private visibility before first publication unless the user explicitly authorizes public distribution.

## Prepare

1. Inspect Git status, remote releases/tags and the intended changes. Preserve unrelated local work. Use the next unused patch version for compatible fixes; choose a larger version when the scope warrants it. Update `project.godot`, current-version documentation and the play-guide heading. The HUD reads the configured version. Save schema and network protocol are separate compatibility numbers.
2. Use Godot 4.5.1 standard and official matching Windows x86-64 export templates. Keep checksum/TLS verification enabled. Run the relevant existing tests with disposable user data; graphical changes need actual rendered checks and multiplayer changes need real host/player processes. See `tests/README.md`.
3. Record the actual passed/failed/skipped checks in release notes. Preserve the original 2014 rules and existing automation limitations. A Linux run of the Windows pack does not establish native Windows launch. Use a prerelease while native Windows validation remains outstanding.
4. Commit the intended source and release metadata using the existing Git identity. Build from that clean, known commit. Keep executables, logs, screenshots and campaigns outside the source checkout. Do not bundle campaign snapshots, private PDFs or live saves in the player release.

## Build and verify

From the project root in PowerShell, with `$Godot` set to the verified engine executable and `$ReleaseDir` set to a new output folder outside the checkout:

```powershell
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
$Portable = Join-Path $ReleaseDir 'Hearthtable_Portable.exe'
if (Test-Path $Portable) { throw 'Choose a new output directory; do not overwrite a release.' }
& $Godot --headless --path . --export-release 'Windows Desktop' $Portable
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
Get-FileHash $Portable -Algorithm SHA256
```

Check the export log for script/resource errors even if its exit code is zero. The tracked preset embeds the pack. The player download is **one `.exe`**, without a ZIP, installer, Godot installation or separate asset folders. Attach its SHA-256 text file and a build manifest separately; include source commit, clean/dirty state, engine, product version and protocol in the manifest.

Test the exported resources, graphical interactions, local multiplayer and synthetic portable campaign creation/restoration. A portable **campaign copy** contains private DM content; publish the plain exported player executable. Record native Windows/GPU/audio and external internet tests as outstanding until actually performed.

## Publish and retain

1. Verify GitHub API and asset-upload access, the destination repository and visibility. Native Git access alone does not establish release API permission. Do not request secret values in chat; reuse existing authentication.
2. Push the intended source branch without force. Create a unique annotated version tag at the tested commit, and push only that tag. Do not tag an older remote commit when local fixes are missing remotely.
3. Create a **draft** GitHub Release for that existing tag. Upload `Hearthtable_Portable.exe`, `SHA256SUMS.txt` and `build-manifest.json`. The executable belongs in release assets, not ordinary Git history. GitHub Release assets support files up to 2 GiB; check the current artifact size before upload.
4. Confirm asset names, sizes and checksums, then publish the release on the user's existing request. Retain prerelease status when native Windows verification is pending. Do not change visibility, buy services or add external hosting as a workaround for access failures.
5. Download the uploaded executable to a fresh location and compare its SHA-256 with the manifest. Report the actual release/download URL and unresolved validation limits. A prepared local build or a draft configuration is not a published release.

If access is blocked, finish the clean source checkpoint, build, checksums, notes and exact publication commands, then identify the missing network/authentication permission. Do not claim publication succeeded. Future publication still requires a user release request.
