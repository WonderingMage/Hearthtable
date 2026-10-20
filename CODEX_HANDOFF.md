# Hearthtable Lite development handoff

This branch is **Hearthtable Lite 1.0.1** (`edition/lite`, prepared update; latest published release `lite-v1.0.0`), Godot 4.5.1, protocol 11, schema 1. Read `docs/lite.md` and `assets/help/lite.txt` for the active product contract. The user explicitly requested this separate DM-led edition; classic Hearthtable remains on `main` with its existing releases.

`main.tscn` now loads `lite_app.gd`. `lite_board.gd` retains the rotatable isometric view for both roles and lets players drag their assigned pawns, with no distance cap during exploration and a cumulative own-turn allowance in DM-started combat. Players cannot control doors. `lite_sheet.gd` provides the expandable complete sheet. `lite_rules.gd` is the first host command boundary and creates private rolls, DM prompts, intentions, manual decisions, private initiative and allowlist player snapshots. `lite_creature.gd` validates/constructs data-only custom geometry. Shared map, save, lobby, PDF, miniature, asset-sync and update modules remain available.

There is no automatic attack/save/damage or encounter director in Lite. Movement limits apply only to players in DM-started combat; DM placement remains unrestricted. The DM explicitly chooses effects and resource spending. Do not route a new sheet button around `lite_rules` into classic automation. Enemy health/AC/initiative, hidden actors/objects, DM rolls/notes and decisions are excluded before networking; fog masks art and geometry before transfer. New props/creatures start concealed; blackout sends an empty scene while preserving assigned sheets.

Lite uses the **Hearthtable Lite** user-data directory and accepts only matching Lite update provenance. `tools/release_lite.py` builds a clean `lite-vVERSION` tag, exported Windows resources, real three-process networking, Windows/Linux portable copies and compiled-update/rollback validation. Native Windows/GPU/audio/external internet remain untested. Each future coding task prepares the update and change list; release publication still requires a request.

The initial public prerelease is https://github.com/WonderingMage/Hearthtable/releases/tag/lite-v1.0.0, built from immutable tagged source `ae2846ddc17f8630439def92ebaf3a13b94dc15f`. CI passed 212 assertions and uploaded all four assets, but its token could not finish publishing; the existing repository connection published the verified draft. See `docs/releases.md` for that fallback. Separate validation passed 57 rendered UI assertions against exported Windows resources and 39 graphical DM/two-player network assertions. Published downloads and the real updater provenance were verified. Native Windows/GPU/audio/external residential internet checks remain outstanding.

The 1.0.1 follow-up fixes DM spell-area deletion (board eraser, individual list removal, clear-all and undo) and the local throne-map import size cap while preserving remote command limits and scene validation. `character_creator.gd` now guides seven steps using `creation_catalog.gd` for structured 2014 choices, standard array / 27-point buy, optional basic starting totals, catalog gear/spells and import-preserving review. Imports keep unknown choices, final bonuses and custom spells; class changes on imports never replace the mechanical sheet. This is not a full progression engine. `tests/lite_creation_ui.gd` covers the complete rendered flow and both reported UI regressions. Prepare the 1.0.1 update but publish only on a new release request.

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
