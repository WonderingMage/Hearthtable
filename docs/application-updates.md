# Importable application updates

The owner requested code changes as files importable through Settings. From 0.12.0, each release provides the full single-file `Hearthtable_Portable.exe` and a matching `Hearthtable-VERSION.hearthupdate`. The EXE includes the engine and current application; the update contains the complete application resources for the compatible installed engine. A coding task prepares the package and updates `docs/release-highlights.json`; publication still happens only on an explicit release request.

Download the new 0.12.0 EXE once to obtain the importer. The 0.11.1 executable predates it. Later application code/assets changes can use Settings import. Engine changes, an incompatible updater API, new bootstrap/autoload requirements or save-schema changes can require a new EXE foundation.

## Player workflow

1. Download the `.hearthupdate` asset from the established public repository's release.
2. Open **Settings → Import application update**, select the file and review its version/change list.
3. The app verifies the complete file against the exact asset digest in the public GitHub release. It uses only the fixed HTTPS `api.github.com/repos/WonderingMage/Hearthtable/releases/tags/vVERSION` origin, without asking for a token. Internet is required for this step. Drafts, mismatched assets and altered files are refused.
4. Disconnect the multiplayer session, then choose **Install update & restart**. The current campaign is saved, a separate pre-update backup is written, and the application restarts into the staged resources. All players and the DM should use the same compatible release.
5. **Settings → Roll back application update** restores the retained previous application resources, or the built-in version when no prior package exists. It requires a restart and keeps campaign saves. The pre-update backup remains available if a separate campaign restoration is needed.

Normal campaigns and maps stay under the application's existing user-data folder. Update files and private campaign backups live in `user://updates/`; they are never published as player assets. The running EXE is never overwritten. Portable campaign copies embed the currently running application pack and campaign together, including when another update/rollback is pending, so they do not require the original update folder on a new computer.

## Format and startup

The binary format is an ASCII `HEARTHUPDATE01\n` marker, a little-endian 32-bit JSON byte length, a bounded UTF-8 manifest, and one Godot PCK. The manifest declares application/version, engine 4.5.1, updater API 1, minimum EXE foundation, protocol, schema, source commit, exact payload size/SHA-256 and bounded text changes. Payloads are limited to 200 MB, manifests to 64 KiB, and no archive paths are extracted. The full-file digest must separately match the published release asset. A checksum printed inside an unverified file does not authorize code execution.

The stable **first autoload**, `UpdateBoot`, validates the installed pack and mounts it before `World` is loaded. This allows actual compiled script/resource replacement. It overrides the displayed version from the verified manifest. The app confirms successful startup after building its first UI frame. An interrupted unconfirmed startup triggers rollback on the next launch; corrupt installed resources fall back before mounting. Package installation and registry writes use temporary files and renames. The previous package remains available.

Application updates deliberately contain executable code. This authorization does **not** apply to character sheets, map/design/scene imports, which retain their data-only validation and never load imported scripts. Runtime packages must come from the verified project release. Development tests use synthetic metadata at the pure verification boundary and never enable an unverified-import switch in the player UI.

## Building and release checks

`tools/release.py` exports Windows/Linux programs plus a Windows-compatible complete application PCK from the clean exact tag. `tools/make_update.py` packages that PCK and the source's `docs/release-highlights.json`. It fails if the version/commit/pack format is invalid or the output already exists. The release builder uploads only the plain EXE, `.hearthupdate`, checksum file and build manifest, and verifies downloaded copies before publication. Older releases/tags/assets remain intact.

`updates.gd` covers failure handling and preservation. `ornate_ui.gd` exercises the actual Settings controls and backup/offline gate. `tools/test_updates.py` independently compiles a synthetic changed World, then runs real exported processes through install, updated startup, portable rebaking, fresh-user-data transfer and rollback. These checks demonstrate code replacement, rather than only manifest parsing. Native Windows, hardware/audio and external internet testing remain separate validation requirements.
