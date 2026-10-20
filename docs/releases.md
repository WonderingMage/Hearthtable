# Lite releases

On `edition/lite`, follow `docs/lite.md` and use `tools/release_lite.py`, unique annotated `lite-vVERSION` tags, `Hearthtable_Lite_Portable.exe` and `Hearthtable-Lite-VERSION.hearthupdate`. Do not replace classic `v*` tags/assets or merge Lite's product configuration into `main`. Both editions remain public in the existing repository under the owner's authorization. This initial Lite release is explicitly requested.

Build locally from the exact clean tag before pushing the release tag. The tag workflow selects the Lite builder, uses official Godot 4.5.1/checksum-verified templates, runs the exported-resource suites, real DM/two-player UDP, both portable restoration routes and compiled updates. It uploads a draft, verifies downloaded hashes and GitHub asset digests, then publishes as a prerelease. Only the plain EXE, matching update, SHA256SUMS and build manifest are player release assets.

Record separate rendered UI/network evidence in release notes, preserve source/old campaigns, verify fresh public downloads and updater provenance after publication, and retain the native Windows/GPU/audio/external internet limitations. Lite updates are fixed to the `lite-vVERSION` provenance and product name; classic packages are refused.

GitHub can allow the Actions token to create a draft and upload assets while rejecting the final release edit with `Resource not accessible by integration`. This happened for `lite-v1.0.0`; the build and all 212 assertions had passed. Inspect the draft, download all four assets, and verify their GitHub digests, SHA256SUMS and clean-tag build manifest before finishing publication with the existing authenticated repository connection (`gh release edit lite-vVERSION --draft=false --prerelease --notes-file /path/to/verified-notes.md --repo WonderingMage/Hearthtable`). This remains subject to the owner requesting that release. Do not rewrite the tag, replace a published asset or claim the failed Actions run published it. After publication, download the assets again and check the real updater's `inspect`/`official` result against the published release JSON. No extra token or permission change was needed to finish the initial Lite publication this way.

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
