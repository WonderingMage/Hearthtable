# Working on Hearthtable Lite

This is the separate `edition/lite` line: **Hearthtable Lite 1.0.2**, Godot **4.5.1**, protocol **11**, campaign schema **1**. Read `docs/lite.md`, `assets/help/lite.txt`, `CODEX_HANDOFF.md` and `tests/README.md`. Classic Hearthtable stays on `main` and existing `v*` releases; do not merge Lite's product configuration into classic without a new user instruction.

- The user explicitly replaced automated RPG combat with a DM-led VTT. Both roles use rotatable isometric views. DM placement is free, with measured distance. Players move only assigned heroes: no distance cap outside combat, cumulative allowance on their own turn after the DM starts combat. Only the DM opens/closes doors.
- Players roll and submit intentions from their own expanded sheets. The DM controls outcomes, initiative order, HP, conditions, resources and board visibility. Preserve the host gateway; do not restore auto attacks, spell saves/damage or encounter triggers. Player movement budgets are explicitly required in DM-started combat; DM placement remains free.
- Player privacy applies to packets and asset downloads. Use Lite's allowlist snapshot, neutral public tokens, private roll/inbox filtering, pre-transfer fog redaction and blackout placeholder. New enemies/props start concealed. Never transmit real enemy health/AC/initiative or hidden models/objects to players.
- Creature/map/character imports stay data-only. Custom geometry is bounded by `lite_creature.gd`; no imported code or arbitrary resource paths. Keep models/maps self-contained in campaigns, scenes and portable copies.
- Lite has separate saves and update provenance. Build with `tools/release_lite.py`; tags are `lite-vVERSION`, primary download is `Hearthtable-Lite-VERSION-Windows.zip` containing a Windows installer; its internal build payload remains `Hearthtable_Lite_Portable.exe`, updates are `Hearthtable-Lite-VERSION.hearthupdate`. Classic and Lite updates are not interchangeable.
- For coding tasks, prepare the compatible update and update `docs/release-highlights.json`. Publish only when requested; the initial Lite 1.0.0 release was explicitly requested; later coding requests prepare an update without automatically publishing. Public releases in this repository remain authorized.
- Validate changes using disposable **Hearthtable Lite** user data. Use real DM/two-player processes for authority/privacy and rendered UI for sheet/board controls. Distinguish native installer/headless Windows checks from untested physical GPU/audio and external internet play. No private campaigns, PDFs, QA logs, builds or `.godot/` in Git/player release assets.

- The owner replaced new-character creation with import-only review. Use `character_review.gd`: a PDF opens an isolated full-sheet draft with live miniature preview, gear equipped/attuned and spells prepared. Retain unknown choices and final totals; player imports still require DM acceptance. Do not restore the wizard.
- Install app and versioned tracked source under Program Files (x86), with desktop/Start Menu shortcuts. Keep mutable campaigns/updates in AppData and retain them on uninstall. `docs/windows-installation.md` describes native validation and optional trusted signing. Never claim unsigned binaries have a verified Windows publisher, request keys in chat, disable Windows security, or enroll/buy signing without authorization.

## Shared/classic guidance retained for reference

The earlier guidance below describes classic 0.12.0. Its tactical camera and automatic combat requirements apply to classic only; Lite's explicit contract above supersedes them on this branch.

# Working on Hearthtable

Read `CODEX_HANDOFF.md`, `tests/README.md` and the in-app help before changing behavior. This is Godot 4.5.1, original 2014 fifth edition, version 0.12.0/protocol 10 (older 0.11.1 uses protocol 9).

- Preserve host authority and player ownership checks. Filter DM secrets before producing player snapshots or asset manifests.
- Preserve the DM isometric and player tactical views. Do not reintroduce archived camera modes without a user request.
- Validate scene recipes, dimensions, content sizes and imported identifiers. Scene/character/design imports remain data-only: never execute their scripts or accept arbitrary resource paths. The owner separately authorized application code updates through verified `.hearthupdate` release packages; see `docs/application-updates.md`.
- Keep imported images and custom recipes self-contained in scene exports, player downloads and portable campaign copies.
- Test changed behavior with the relevant existing suite using disposable user data. For network changes, exercise actual host/player processes, not just direct command calls.
- Distinguish Linux validation of the exported Windows pack from a native Windows launch. Do not claim full rules coverage or performance results that have not been measured.
- Keep machine paths, `.godot/`, temporary test data, campaign saves and private PDFs out of source deliverables. Use official export templates when rebuilding.
- For coding changes, prepare the importable application update along with the build and update `docs/release-highlights.json` with the actual changes. Use `tools/make_update.py` / `tools/release.py`; do not invent ad-hoc code-import formats.
- Publish a new release only when the user requests one; ordinary coding requests do not automatically publish. Follow `docs/releases.md` and attach the single portable `.exe` and matching `.hearthupdate` as release assets.
- The owner has authorized public releases in the existing `WonderingMage/Hearthtable` repository. Preserve its public visibility; do not repeat that approval for subsequent requested releases.
