# Hearthtable Lite development handoff

Release-checkpoint validation exposed the known intermittent ENet zero-channel
send error even with the existing application-level sync guard. Pinned Godot
4.5.1 `SceneMultiplayer::_del_peer` sends built-in peer-relay announcements
before the game's disconnect callback and can target a second departing guest.
Lite hosts now disable that unused SceneMultiplayer server relay; all gameplay
already travels through the DM. The real two-player test checks that each guest
has only the DM as a transport peer while retaining the existing ownership,
privacy, movement, spell-decision and concurrent-departure checks. This is not
a diagnosis of the owner's separate native memory-access popup. Network errors
remain fatal; improved role diagnostics retain all peer errors and exit codes.

The owner now explicitly authorizes an automatic new installer release after
every **five accepted improvements**. `tools/agent-loop/releases.mjs` keeps a
private durable counter (new accepted cycles only; failed/no-change cycles do
not count). On the next run after five, the parent launcher, outside workers,
prepares an immutable versioned source commit in an external worktree, performs
full local rendered/network/native-build validation, and pushes only a new
Lite tag. Existing `release.yml` gates installer ZIP/update publication. Later
runs poll without agents and verify downloaded assets/digests, source/version
and native installer evidence before consuming the batch and fast-forwarding
the local development branch. Fully validated drafts can be finished with the
owner's GitHub CLI login. `release` retries/checks a due batch without models.
The owner must install/sign into GitHub CLI on their PC; Codex login is separate.
See `docs/agent-loop.md`. The Codex Review button is not needed; the website's
Actions/Releases pages are a fallback. No new release or real five-cycle batch
was started from this cloud checkout; the owner's app commits remain local.

Current diagnostic follow-up: the owner saw a native Godot 4.5.1 memory-access
error during their still-active local run. Cause/stage is unverified; Windows
fault module/logs and the final cycle report are pending after it finishes.
Their pasted `rg: scripts/*.gd ... error 123` is a separate Windows wildcard
problem, not evidence for the native crash's cause. The worker prompt now uses
directory plus `-g '*.gd'` filtering and requires unresolved crashes to block
acceptance. Preserve work and diagnostics; do not reinstall tools, relax errors
or assume a successful CI run fixes the physical PC's native crash.

The latest instruction broadens the local loop from bug fixing to substantial
campaign feature development, using **GPT-6 Luna (`gpt-6-luna`)** for coordinator,
Builder, Tester and Critic. Invocation-scoped `model` and
`agents.default_subagent_model` settings pin it without changing global config;
unavailable model access pauses rather than falling back. Startup/runtime logs
record requested settings, not proof of account entitlement. Read
`docs/campaign-experience.md`: first priority is a DM-approved Druid -> Dire Wolf
Wild Shape that updates the effective sheet and safely restores the base form.
It includes 2014 eligibility/subclass rules, distinct HP, inherited traits,
gear/concentration, DM-controlled reversion and owned-sheet multiplayer/save
coverage. The broader class/scenario rotation uses Beyond-style organization
and explicit homebrew decisions. Those are development goals, not implemented
app features in this cloud tooling commit. Preserve the owner's newer local
app commits. Ten-minute scheduling stays opt-in; activation remains unconfirmed.

Latest owner checkpoint (October 21, 17:31 UTC): the real manual cycle was
ACCEPTED. It restored Shield's missing 2014 reaction trigger in the full spell
view, casting proposal and DM inbox, committed the fix and built matching local
EXE/update artifacts. Its report is under the owner's loop state in
`runs/2026-10-21T17-31-29-163Z-9590b488/report.json`. Nothing was published or
installed. Those app commits are local to `automation/lite-improvements`, not
this cloud checkout. The owner now requests a **10-minute** schedule; the
launcher, first-start delay, native scheduler check and documentation use that
cadence. Overlaps remain skipped and failures pause future model work. Enable
has not been confirmed on their PC. Fetch and normally merge these tooling
changes without discarding local app commits, then complete a manual cycle on
the resulting clean revision before `enable` (readiness is commit-specific).

Earlier owner checkpoint: their expanded Python/Godot probe passed on the real
PC. The preserved spell-slot preview fix passed 237 native core/UI assertions
and was committed locally as `564eba1cdccd712f468fc9e8e35fd3c66a861a2e` on
`automation/lite-improvements`; that commit is not on this cloud branch. An
untracked `top` item was moved to a private backup outside the worktree. The
next actual three-worker cycle fixed ritual/innate proposals retaining higher
slots, passed 250 assertions and both independent approvals, but could not
create `%USERPROFILE%/Dev/Hearthtable/.git/worktrees/Hearthtable-Autopilot/index.lock`.
It left three modified files (sheet, UI tests, highlights), no new commit and
no matching build/update. Preserve those edits and the prior local commit.
The launcher previously granted only the Git common directory. Pinned Codex
protects the exact worktree admin directory separately. The profile now grants
that exact directory and shared objects/refs/logs separately, leaving the broad
common directory read-only for linked worktrees. This avoids reusing an earlier
denied common-directory write capability. The free prerequisite checks real metadata writes
using owned temporary files, without touching index/refs/source. Blocked cycle
reports are read before checking for remaining edits, preserving the actual
failure instead of replacing it with a generic dirty-worktree message. Native
Windows validation passed on tooling source
`eb362737ca4efc94919156f98f00845c05780e5c` in run `39642938728`:
32 launcher/runtime checks, then a real Codex 0.163 linked-worktree test outside
TEMP reproduced the old index.lock denial and staged/committed successfully
using the corrected grants. Its `.git` pointer stayed protected and the main
checkout's HEAD/source stayed unchanged. The same workflow passed actual sandbox
Python/Godot/Git prerequisites, 233 base source/UI assertions, 37 multiplayer and
154 compiled-Windows assertions plus matching update preparation and unchanged
ordinary-save sentinel/source. The owner's local 250-assertion candidate is a
later app change; do not confuse that with this cloud branch's 233 baseline.
The owner must save that reviewed candidate in normal PowerShell, fetch and
merge the tooling updates while preserving their local app commits, and pass
the expanded free probe/build before another paid cycle. Their app commits
diverge from origin/edition/lite: use a normal merge after committing preserved
edits, never reset/clean/force a fast-forward. A successful automatic commit on
their PC and schedule enable remain pending. No release or real model cycle
was started by CI; no Windows ACLs need to be edited by the recovery commands.

Current local-loop blocker (October 21): the owner passed the actual sandbox
Python probe after the scoped RX repair, then Godot's no-autoload isolation
probe resolved the correct disposable save path but logged `Failed to read the
root certificate store` at Windows engine line 2548. Pinned Godot 4.5.1 falls
back to its bundled CA set when ROOT is unavailable. The QA helpers now request
verbose evidence and classify only that exact official-engine diagnostic as
recoverable when the same process confirms the bundled certificates loaded.
Raw diagnostics remain in logs; all other errors, failed TLS parsing, exit
codes, assertion summaries and path checks remain enforced. Python and Godot
startup/isolation are both checked by `agent-loop.mjs probe` before model usage.
No certificate-store permissions, TLS validation, gameplay or app version changed.
Native sandbox validation passed on helper source
`d9eb2ad7c15b6699228a5482d4c1d93e6e2795a1` in run `39574388306`:
29 launcher/runtime checks plus actual Codex 0.163 sandbox prerequisites,
233 source/UI, 37 multiplayer and 154 compiled-Windows assertions, matching
update preparation, unchanged source and normal-save sentinel. The real
restricted account reproduced the ROOT-store failure and confirmed the bundled
CA fallback across probes, imports, tests and compiled execution. Godot's existing
folder is pinned through `HEARTHTABLE_TOOLCHAIN` and given a read-only profile
entry. This fresh VM needed scoped RX for its Godot tool folder as well as the
disposable Python copy; this CI-only grant does not modify the owner's PC.
Normal Windows run `39574388325` passed source/network/compiled checks too.
The owner already launched Godot inside workers; do not infer they need a
reinstall or new ACL change from the fresh VM. They must fetch/fast-forward and
pass the expanded free probe on their PC before another paid cycle. A successful
manual model cycle and schedule enable remain pending. No release was published.
See `docs/agent-loop.md`.

This branch is **Hearthtable Lite 1.0.2 in development** (`edition/lite`; latest published prerelease remains `lite-v1.0.1`), Godot 4.5.1, protocol 11, schema 1. Read `docs/lite.md` and `assets/help/lite.txt` for the active product contract. The user explicitly requested this separate DM-led edition; classic Hearthtable remains on `main` with its existing releases.


The latest owner instruction supersedes the historical seven-step creator and single-EXE delivery requirements. `character_review.gd` replaces the deleted creator with PDF-only full-sheet review and live miniature preview; equipped/attuned and prepared choices require confirmation, imports retain final totals/custom choices, and DM approval remains mandatory for remote submissions. The Lite desktop has company cards, health/selection states, a two-row DM navigator and illustrated action cards. Bundled prepared maps now use `import_prepared_scene` with an allowlisted catalog ID, loading the original image locally. The owner confirmed the recurring 1.0.1 error happens at **Add to scene library**, not activation.

Future primary downloads are installer ZIPs: app plus versioned tracked source in Program Files (x86), desktop/Start Menu shortcuts, AppData saves/updates retained on uninstall. See `docs/windows-installation.md`. `release_lite.py --validation` builds a clean branch without tagging/publishing; the Windows workflow compiles/tests the installer before retaining a reviewable ZIP or publishing a requested tag. Optional trusted certificate signing covers app/setup/uninstaller. No signing identity is configured; free SignPath eligibility/application requires owner input, and its integration is not yet configured. Do not claim unsigned builds have a verified publisher.

A native Windows probe of the **actual published 1.0.1 EXE** passed 12 headless assertions in Actions run `39528691527` (offline DM, hosted lobby, hosted table), using the full throne image. Linux rendered tests also passed the actual Add button. This did not reproduce the owner's environment and does not replace testing the new small-ID UI path or installed Windows build. Hardware GUI/audio and external residential internet remain separate checks.

Final 1.0.2 validation is recorded in `docs/validation-lite-1.0.2.md`: clean application source `7cde9255d14c2a05240ac8a3dd83efed18403611`, successful installer artifact run `39531379652`, 230 build assertions, 79 rendered exported-resource assertions and 12 native installed-Windows assertions plus setup/shortcut/source/uninstall/save checks. Publication was explicitly skipped. This documentation checkpoint does not change the tested application. The build remains unsigned pending a trusted signing identity.

The owner is setting up a local 30-minute three-worker loop. `tools/agent-loop.mjs` and `docs/agent-loop.md` prepare Doctor/one-cycle/enable/pause/status controls for the separate `automation/lite-improvements` worktree. Node launches npm's Codex JS entry without PowerShell policy changes. Nothing is enabled automatically. The user has installed Codex CLI 0.163.0 and signed in; their worktree is under `%USERPROFILE%\Dev\Hearthtable-Autopilot`. Do not start repeating usage until a successful manual cycle and an explicit local enable command. Missing Godot/editor/isolated testing/build prerequisites must be reported before edits. All 13 native Windows launcher checks passed on application-tooling source `9393717dd75f100c2f77bbc13f205de502a53729` in Actions run `39556168335`, using fake agents and a temporary disabled task, not actual improvement cycles. The owner subsequently completed the local tool setup and baseline checks described below; the first successful manual cycle remains pending confirmation. This tooling does not change or repackage the tested 1.0.2 app.

`tools/lite-local.mjs` now provides pinned Windows Godot/editor/template setup plus safe source, graphical, three-process network and candidate EXE/update validation. See `docs/agent-loop.md`. It uses child-only APPDATA overrides and an autoload-free exact-path probe; XDG variables alone remain insufficient on native Windows. Python 3.11+ is needed for network/build. Setup does not start tests or agents. Native Windows run `39561758442` passed on helper source `d50ece5dd8c3f1df237ba7d2e4cde0375c8cc97b`: 7 harness checks, official setup, 154 source + 37 network + 154 compiled-EXE assertions, matching update preparation and unchanged normal-AppData sentinel/source. Launcher run `39561758352` passed all 13 checks on the same source. A separate Linux network run hit an intermittent concurrent-guest-shutdown `Unable to send packet on channel 0, max channels: 0` despite its 37 passing assertions; the harness rejected it correctly. Preserve this concrete first-cycle investigation candidate rather than suppressing the error. No gameplay source changed. The owner reported successful local Windows validation on October 21: 233 core/rendered assertions, 37 real network assertions and a separate 154-core-assertion run. The first successful agent cycle remains pending confirmation; nothing has enabled a loop or published a release.

The owner explicitly wants the improvement loop to inspect missing/incomplete/inaccessible spell descriptions and useful improvements to existing VTT functions. `tools/agent-loop/prompt.md` carries those priorities through player spell views, casting proposals and DM review, preserving 2014 references, custom/imported text and DM decisions. A basic source audit found all 319 bundled spell entries have nonempty `desc`, casting time, range, components and duration fields; that is not proof of complete rules text or correct UI presentation. Optional upcasting fields need not exist for every spell. No app behavior was changed by this instruction update. If a cycle already started, its prompt was captured at launch; update the local worktree only once it finishes and preserve any candidate commits.

The first owner-run manual cycle on `a38309fd2285e56208fe265fbf6387abfe1c2aa4` stopped cleanly before edits because Python lookup failed inside the agent session, despite successful ordinary Windows tests. The owner confirmed standalone Python 3.13.7 at `%LOCALAPPDATA%\Programs\Python\Python313\python.exe`; do not ask them to reinstall it. `tools/python-runtime.mjs` now verifies the direct interpreter, searches normal per-user installs without the launcher, preserves actual startup diagnostics and supports `--python` / `HEARTHTABLE_PYTHON`. The launcher resolves Python before model usage, records its path in private `runtime.json` and passes it into Codex and its shell policy. The helper re-verifies the pinned interpreter. The agent process now has an explicit working directory; prompt instructions require non-login Windows shells to avoid profile directory resets. Worker findings must come from actually launched workers with IDs; prerequisite-blocked reports must say workers were not started. The fix at `9ac9b36eda3a5350538d2646509927b146c8c13b` passed all 24 native Windows launcher/runtime checks in Actions run `39565904566`, including empty-PATH per-user discovery, exact interpreter/environment/config handoff and a fail-before-agent guard. Native workflow run `39565904592` also passed official setup, 154 source + 37 network + 154 compiled-EXE assertions, matching update packaging and the unchanged normal-user-data sentinel. No real model cycle ran in CI. A retry inside the owner’s actual Codex sandbox is still required before enabling the schedule.

The owner retried after the Python pin and still got `spawnSync ...Python313\python.exe ENOENT`; the prerequisite report confirms no workers or edits. Ordinary Windows CI did not establish access inside Codex. Actual sandbox run `39568106883` reproduced the invisible executable; a read-only profile entry alone was insufficient. A read/execute ACL grant to Codex’s own `CodexSandboxUsers` group on only the Python installation made it runnable, then run `39569021545` exposed the JS realpath walker trying to lstat a protected AppData parent. Runtime resolution now uses `fs.realpathSync.native` in the sandbox-facing helpers, preserving parent-side checkout identity. Source `b9e7e71efc6dfec72fa38013a9f9bf5bb1b6b3f4` passed native run `39570420518`: 27 launcher/runtime checks and the real pinned Codex 0.163 sandbox starting per-user Python, without model calls. Godot helper source `0d742102cf43e7e87e417146b0e6e597a9ca8a9e` also passed run `39569786442` (154 source + 37 network + 154 compiled assertions, update packaging, unchanged normal data/source). `agent-loop.mjs probe` and every run now test the actual sandbox before model usage, retaining private visibility/startup diagnostics, preserving pauses and never creating readiness on probe alone. The per-invocation profile extends `:workspace` with read-only access to the verified Python folder and retains the existing source/report/Git write scope. The owner must apply the documented scoped RX grant in ordinary PowerShell and pass the no-model probe before another agent cycle. Do not grant write/full-control to Python or read access to whole AppData, alter personal saves, or disable sandboxing. `docs/agent-loop.md` has the exact owner commands. The owner’s PC probe, successful three-worker cycle and schedule enable remain pending.

`main.tscn` now loads `lite_app.gd`. `lite_board.gd` retains the rotatable isometric view for both roles and lets players drag their assigned pawns, with no distance cap during exploration and a cumulative own-turn allowance in DM-started combat. Players cannot control doors. `lite_sheet.gd` provides the expandable complete sheet. `lite_rules.gd` is the first host command boundary and creates private rolls, DM prompts, intentions, manual decisions, private initiative and allowlist player snapshots. `lite_creature.gd` validates/constructs data-only custom geometry. Shared map, save, lobby, PDF, miniature, asset-sync and update modules remain available.

There is no automatic attack/save/damage or encounter director in Lite. Movement limits apply only to players in DM-started combat; DM placement remains unrestricted. The DM explicitly chooses effects and resource spending. Do not route a new sheet button around `lite_rules` into classic automation. Enemy health/AC/initiative, hidden actors/objects, DM rolls/notes and decisions are excluded before networking; fog masks art and geometry before transfer. New props/creatures start concealed; blackout sends an empty scene while preserving assigned sheets.

Lite uses the **Hearthtable Lite** user-data directory and accepts only matching Lite update provenance. `tools/release_lite.py` builds a clean `lite-vVERSION` tag, exported Windows resources, real three-process networking, Windows/Linux portable copies and compiled-update/rollback validation. Native installer/headless validation is described above; physical GPU/audio and external internet remain untested. Each future coding task prepares the update and change list; release publication still requires a request.

The initial public prerelease is https://github.com/WonderingMage/Hearthtable/releases/tag/lite-v1.0.0, built from immutable tagged source `ae2846ddc17f8630439def92ebaf3a13b94dc15f`. CI passed 212 assertions and uploaded all four assets, but its token could not finish publishing; the existing repository connection published the verified draft. See `docs/releases.md` for that fallback. Separate validation passed 57 rendered UI assertions against exported Windows resources and 39 graphical DM/two-player network assertions. Published downloads and the real updater provenance were verified. Native Windows/GPU/audio/external residential internet checks remain outstanding.

The 1.0.1 follow-up fixes DM spell-area deletion (board eraser, individual list removal, clear-all and undo) and the local throne-map import size cap while preserving remote command limits and scene validation. `character_creator.gd` now guides seven steps using `creation_catalog.gd` for structured 2014 choices, standard array / 27-point buy, optional basic starting totals, catalog gear/spells and import-preserving review. Imports keep unknown choices, final bonuses and custom spells; class changes on imports never replace the mechanical sheet. This is not a full progression engine. `tests/lite_creation_ui.gd` covers the complete rendered flow and both reported UI regressions. The owner subsequently requested publication; 1.0.1 is published. Future releases still require a request.

Release validation also caught simultaneous guest departures leaving a stale authenticated peer during ENet polling. `World.sync_all` now checks current transport membership and connected ENet state before sending snapshots. The actual three-process suite waits for both guests to disconnect while the host remains active and verifies ownership returns to the DM.

The 1.0.1 public release is https://github.com/WonderingMage/Hearthtable/releases/tag/lite-v1.0.1, built from immutable tagged source `26af8f4e952d6a4e2be60bf973ee106f58df037c`. It passed 225 release assertions locally and on GitHub, 108 rendered UI assertions against the exact uploaded Windows EXE resources, and 14 actual downloaded-package install/restart/preservation/rollback assertions on the original 1.0.0 Linux foundation. Fresh public downloads match the GitHub digests/checksums/manifest, and the actual updater accepted the published release provenance and source commit. The owner’s existing repository connection completed publication after Actions encountered a 404 when looking up an unpublished draft by tag. The release builder now verifies draft assets using the authenticated release list, and avoids changing the target when resuming an existing draft. These post-tag tooling/documentation changes do not change the released application. Native Windows/GPU/audio/external residential internet validation remains outstanding.

The previous handoff is retained below for shared architecture and classic behavior. Its player tactical view, automated rules and classic asset/tag names do not describe this Lite edition.

---

# Hearthtable development handoff

Hearthtable is a native Godot **4.5.1** tabletop for **original 2014 D&D 5e**, version **0.12.0**, campaign schema **1**, network protocol **10** (older 0.11.1 uses protocol 9). Open the folder containing `project.godot` in Codex and Godot. In the source companion this is `Hearthtable/Source`.

## Product requirements

- Keep the 2014 rules baseline. Do not silently substitute 2024 rules or Baldur's Gate 3 rules.
- The DM uses a rotatable isometric view; players use the tactical 3D view. Shift-drag rotates. Preserve the gilded HUD and readable native-resolution controls.
- The host resolves movement, ownership, dice, attacks, resources, encounters and scene changes. Player requests must not bypass those checks.
- Typical speed 30 means 30 feet of cumulative movement per turn, rather than a fresh allowance per click. Other speeds, terrain and Dash apply.
- Rooms conceal connected space through authored walls and closed doors. Clicking an open doorway moves onto it; Door/E controls closing. Occupied doorways cannot close. Linked gates change together.
- Players automatically download the active custom scene's PNG and design recipes on joining or changing scenes. Keep private DM notes, future scenes and battle-zone geometry out of player state.
- The player download is one directly runnable Windows executable. Ordinary working autosaves remain in OS user data. Portable copy creates a new executable containing a campaign snapshot.
- Maps and assets should remain editable, reusable and exportable in self-contained `.hearthscene` packages. The current importer accepts validated procedural design recipes, not arbitrary scripts or model plug-ins.

## Continue in Codex

1. Extract the optional source companion and open `Hearthtable/Source` as the local project. The portable executable alone is not the editable source.
2. Read this file, `AGENTS.md`, `tests/README.md`, `assets/help/play.txt` and `assets/help/automation.txt`.
3. Initialize Git locally if the folder is not already tracked, then commit the starting version. Keep `.godot/`, local campaign saves and test user-data directories out of Git.
4. Give Codex the next concrete change and any new map references. The files capture the current requirements; do not assume the complete chat automatically transfers.

## Architecture

| Area | Main files |
| --- | --- |
| Host state, commands, snapshots, RPCs | `scripts/world.gd` |
| 2014 combat, route and range checks | `scripts/encounter.gd`, `scripts/combat*.gd` |
| Board, cameras, native scene geometry | `scripts/tabletop3d.gd` |
| Player/monster action cards and door clicks | `scripts/tactical_hud.gd`, `scripts/battle_ui.gd` |
| Walls, doors, connected rooms | `scripts/room_geometry.gd` |
| Build catalog, collision, placement | `scripts/build_system.gd`, `scripts/build_models.gd` |
| Imported procedural designs | `scripts/map_models.gd` |
| Scene package validation | `scripts/scene_files.gd` |
| Automatic downloads, verified disk cache | `scripts/scene_sync.gd`, `scripts/scene_download_ui.gd` |
| Day/night and capped raster lights | `scripts/scene_lighting.gd` |
| Supplied prepared maps | `assets/scenes/sanctum_crown.json`, `assets/scenes/ember_rift.json` |

Use the actual filenames present in the project when navigating; combat support is split across several scripts. `World` is an autoload and `main.tscn` is the entry scene.

The new scene downloader uses SHA-256 content IDs, 24 KiB chunks, a 1.5 MiB/s aggregate host cap, bounded PNG/JSON data and `user://scene_cache`. A player can request only advertised active-scene blobs. Revalidate untrusted imports and network payloads at the host boundary.

## Run and rebuild

Install Godot 4.5.1 and its official Windows x86-64 export templates. From this folder:

```sh
godot --editor --path .
godot --path .
godot --headless --path . --export-release "Windows Desktop" ../Hearthtable_Portable.exe
```

The source companion clears machine-specific custom-template paths. The export embeds its pack in the executable. Keep the include filters for JSON/reference data, and do not bundle personal campaign saves or imported character PDFs.

Linux test examples, always with disposable user data:

```sh
XDG_DATA_HOME=/tmp/hearthtable-test-prepared godot --headless --path . --script res://tests/prepared.gd
XDG_DATA_HOME=/tmp/hearthtable-test-combat godot --headless --path . --script res://tests/combat_range.gd
```

Read `tests/README.md` for graphical and two-process UDP suites. Headless tests intentionally reset their campaign, so never point them at real player data. Graphical tests require an OpenGL display. Use distinct user-data directories for the host and player. Tests for removed camera modes are archived and are not current requirements.

## Character/action development

Read `docs/character-actions.md`. `combat_actions.gd` handles host-resolved contests, source-linked holds, Help and Dodge eligibility. `character_creator.gd` owns an isolated draft for new/imported heroes and cosmetic editing; `mini_appearance.gd` validates cosmetic data and configures the same meshes in preview/board. Player-created/imported sheets require existing DM submission approval. Cosmetic updates have a dedicated owner-checked command; clients cannot change stats through it. Protocol 10 prevents mixing these commands with older releases; save schema stays 1. Publish future versions only on a release request.

## Application updates and interface

Read `docs/application-updates.md`. `UpdateBoot` is the stable first autoload and mounts a verified application pack before `World`. `application_update.gd` handles bounded manifests, fixed-origin release provenance, staged files, startup confirmation and rollback. `update_ui.gd` exposes the Settings flow; it refuses installation during multiplayer. Scene/design imports remain data-only. Keep update state and campaign backups in user data, never the checkout. `portable.gd` embeds the currently mounted application pack when copying an updated campaign.

The release builder exports a complete resource pack, packages it as `Hearthtable-VERSION.hearthupdate`, tests real compiled World replacement/restart/portable transfer/rollback, and uploads it alongside the standalone EXE. Each coding task should prepare the corresponding package and update `docs/release-highlights.json`; publication still needs a release request. Engine/updater-API changes require a compatible new portable foundation.

`chronicle_ui.gd` supplies original painted archetype portraits, dividers and frames; user portraits take precedence. `art/build_chronicle_ui.py` generates the rich fantasy SVG materials and action icons. Rendered UI tests cover native and minimum windows; preserve readable controls and camera roles.

## Current validation and limits

The historical 0.11 release companion included 654 passing assertions across exported-pack rules/data, native OpenGL UI, actual local host/player UDP, custom-scene cold/warm downloads, doors and portable snapshot restoration. Windows resources were exercised using matching Linux Godot; **native Windows launch has not been tested**. A real Windows machine, GPU and external port-forwarded connection remain validation work.

The automation coverage file is authoritative about partial rules. Reactions/opportunity attacks, all subclass features, unusual damage riders, environmental damage, lighting/darkvision rules and some spell effects still require DM adjudication. This is not full D&D Beyond or BG3 parity.

Both supplied map rasters are preserved unchanged. Ember Rift's original image is 570×570; its new native models do not increase the source image's detail. Map geometry follows square-grid approximations. The basalt causeway at M27–N29 is an added playable crossing. The Crown hall is 32×46 squares at 5 feet per square; Ember Rift is 32×32. Source pixel calibration is 33.75 and 17.8125 pixels per square respectively.

`tools/create_prepared_maps.py` recreates the packages with Pillow and NumPy. It expects the original maps in `../upload/image(1).png` and `../upload/image(2).png`, relative to this project. The companion's `Reference/Supplied_Volcanic_Map.png` and `Reference/Supplied_Throne_Map.png` are unchanged copies of those references. Ordinary editing or exporting the prepared scenes does not require that authoring script.
