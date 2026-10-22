# Lite releases

The owner authorizes public releases in `WonderingMage/Hearthtable`. The local
improvement loop now has standing authorization to publish a new installer
release after every **five accepted improvements**, following its local and
GitHub validation gates. See [the loop release checkpoint](agent-loop.md#release-after-five-accepted-improvements).
Other coding tasks prepare updates/artifacts and publish only on request.
Never change an existing published tag or asset.

Future Lite downloads are **installer ZIPs**, replacing the single plain EXE as the primary asset. See [Windows installation and signing](windows-installation.md) for paths, source, tests and publisher limitations. Settings-compatible `.hearthupdate` files remain separate release assets so existing fixed-origin digest verification continues to work.

1. Finish review, relevant rendered/headless/network checks, version/highlights and clean source commit on `edition/lite`. Use Godot 4.5.1, protocol 11/schema 1 unless a separate migration is required.
2. Validate without publication using workflow `release.yml`, current branch, `tag=lite-vVERSION`, `build_only=true`. The proposed tag is only a label here; the builder checks the actual project's version and records `validation=true`. No tag or GitHub Release is created. Download the retained `Hearthtable-Lite-Windows` artifact to inspect the setup ZIP/update/checksums/manifest.
3. When requested, tag the final clean commit with a new `lite-vVERSION` and push it. Linux verifies the source/build/tests and transfers only the player payload, source archive, update and metadata. Windows compiles Inno Setup, optionally signs with a configured trusted identity, installs into Program Files (x86), tests shortcuts/source/native imports, uninstalls and proves AppData survives.
4. The Windows publisher creates/resumes an unpublished draft and uploads exactly the ZIP, matching `.hearthupdate`, `SHA256SUMS.txt` and `build-manifest.json`. It checks downloaded hashes and GitHub digests before publication. The internal raw EXE/source staging archive and QA data are not public assets.
5. Download published assets to verify actual release provenance and updater `inspect`/`official`. Keep older releases for rollback. Native installer/headless checks do not claim hardware GPU/audio or external internet validation.

If Actions uploads and verifies a draft but its token cannot publish, the owner's existing repository connection may finish that requested publication after inspecting all assets/digests. Find drafts using the authenticated **release list**, since tag lookups can return 404 before publication. Do not treat an Actions failure or an artifact-only build as a published release.

## Classic release procedure retained

The following older procedure applies to classic source on `main`, not the Lite builder/product identity above.

# Releases

Publish to `WonderingMage/Hearthtable` only when the user requests a release. A coding request by itself does not trigger publication. The next requested release includes the intended fixes since the previous release, receives a new version/tag, and leaves older releases available. Never overwrite a published tag or asset. The owner explicitly authorized public distribution in this existing public repository; preserve that choice without repeating the visibility question.

The `Portable release` GitHub Actions workflow runs only on a pushed version tag or an explicit manual dispatch with an existing tag. Do not create/push a version tag until the user requests a release. The workflow uses GitHub's built-in token with only `contents: write` to upload assets; no personal token is required. This also avoids cloud-proxy credentials that may work for the API but fail on the separate upload hostname. It calls `tools/release.py` to verify official Godot checksums, build from the clean tag, run the exported headless suites, both portable restoration routes and the compiled-update lifecycle test, upload the plain `.exe`, matching `.hearthupdate`, checksum and manifest, verify a downloaded copy, and publish as a prerelease. An ordinary branch push does not trigger release publication.

For a local Linux verification without uploading, run `python3 tools/release.py --tag vVERSION --output /new/output/folder --toolchain /optional/existing/toolchain`. The tool refuses to run native Windows tests using Linux XDG isolation.

## Prepare

1. Inspect Git status, remote releases/tags and the intended changes. Update `docs/release-highlights.json` so the import screen describes this release accurately. Preserve unrelated local work. Use the next unused patch version for compatible fixes; choose a larger version when the scope warrants it. Update `project.godot`, current-version documentation and the play-guide heading. The HUD reads the configured version. Save schema and network protocol are separate compatibility numbers.
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

Check the export log for script/resource errors even if its exit code is zero. The tracked preset embeds the pack. The full player download is **one `.exe`**, without a ZIP, installer, Godot installation or separate asset folders. The separate `Hearthtable-VERSION.hearthupdate` contains application code/assets for Settings import on an existing compatible portable foundation. `tools/release.py` creates both from the same commit; `tools/make_update.py` packages an exported PCK. Attach its SHA-256 text file and a build manifest separately; include source commit, clean/dirty state, engine, product version and protocol in the manifest.

Test the exported resources, graphical interactions, local multiplayer and synthetic portable campaign creation/restoration. A portable **campaign copy** contains private DM content; publish the plain exported player executable. Record native Windows/GPU/audio and external internet tests as outstanding until actually performed.

## Publish and retain

1. Verify GitHub API and asset-upload access, the destination repository and visibility. Native Git access alone does not establish release API permission. Do not request secret values in chat; reuse existing authentication.
2. Push the intended source branch without force. Create a unique annotated version tag at the tested commit, and push only that tag. Do not tag an older remote commit when local fixes are missing remotely.
3. Create a **draft** GitHub Release for that existing tag. Upload `Hearthtable_Portable.exe`, `Hearthtable-VERSION.hearthupdate`, `SHA256SUMS.txt` and `build-manifest.json`. The executable belongs in release assets, not ordinary Git history. GitHub Release assets support files up to 2 GiB; check the current artifact size before upload.
4. Confirm asset names, sizes and checksums, then publish the release on the user's existing request. Retain prerelease status when native Windows verification is pending. Do not change visibility, buy services or add external hosting as a workaround for access failures.
5. Download both uploaded application artifacts to a fresh location and compare their SHA-256 values with the manifest. Verify GitHub exposes the `.hearthupdate` asset’s `sha256:` digest, which Settings uses to establish fixed-repository release provenance. Report the actual release/download URL and unresolved validation limits. A prepared local build or a draft configuration is not a published release.

If access is blocked, finish the clean source checkpoint, build, checksums, notes and exact publication commands, then identify the missing network/authentication permission. Do not claim publication succeeded. Future publication still requires a user release request.
