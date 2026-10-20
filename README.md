# Hearthtable Lite

A DM-led virtual tabletop for original **2014 D&D 5e**, built with **Godot 4.5.1**. The working source prepares **1.0.1** (latest published: 1.0.0), protocol **11**, campaign schema **1**. Classic Hearthtable remains on `main` and its existing releases; Lite lives on `edition/lite` with `lite-v*` releases and its own saves.

- A rotatable isometric tabletop for both roles. The DM freely moves pieces with live distance measurement, builds/imports scenes, edits enemy sheets and imports bespoke data-only creature miniatures. Players move assigned pawns without a distance cap outside combat; DM-started combat enforces turn and cumulative allowance. Only the DM controls doors.
- An expandable player sheet over the board: abilities/saves/skills, actions, full included spell references, equipment, features, description, notes and extras, plus reviewed PDF import and miniature customization.
- A DM screen with blackout, fog, concealed objects/creatures, private rolls and private manually arranged initiative. Player intentions include the relevant rules and dice; the DM decides targets, effects and resource spending.

Download **Hearthtable_Lite_Portable.exe** from the [Lite release](https://github.com/WonderingMage/Hearthtable/releases/tag/lite-v1.0.0) and run it directly. No installer, ZIP or Godot installation is required. Later compatible Lite updates import through Settings using the matching `.hearthupdate`. Classic and Lite update files are not interchangeable. Native Windows launch is still unverified, so this is a prerelease.

Read the in-app Guide or [Lite documentation](docs/lite.md) for play, sheet coverage, privacy and custom creatures. This independent sheet includes 2014 SRD references and editable homebrew; it has no D&D Beyond account/paid-book integration or complete character progression database.

## Development and validation

The repository root contains `project.godot`; open it with Godot 4.5.1. Read `AGENTS.md`, `CODEX_HANDOFF.md`, `docs/lite.md` and `tests/README.md`. Tests reset campaigns: use proven disposable Lite user data, separate for every network peer. Generated programs, caches, real PDFs and DM campaign copies stay outside source commits.

Use `tools/release_lite.py --tag lite-vVERSION --output /new/output --toolchain /optional/toolchain` for a local clean-tag build. It checks exported Windows resources, a real DM/two-player session, Windows/Linux portable copies and actual compiled updates/restarts/rollback. Graphical sheet/board checks run separately. Publish only on an explicit release request; the tag workflow uses GitHub's built-in token.

Portable DM campaign copies include private notes, hidden scenes, custom creatures and installed updates. Keep those copies private. Ordinary campaigns live in the application's separate user-data folder. Existing classic campaign JSON can be imported into Lite after keeping an original backup.

## Source and notices

Missing source directories were restored from the complete Hearthtable 0.11 source companion. `SOURCE_RESTORATION.md` records provenance and the scope of this import. Original application source licensing is included in `LICENSE.txt`; third-party attribution is in `THIRD_PARTY_NOTICES.txt`, `Reference/` and the asset directories. The existing repository `LICENSE` is retained unchanged.

No campaign saves, imported character PDFs, generated executables or Godot cache files are included. Prepared map images are embedded in their scene JSON assets. Public reference PDFs remain available through the links in the notices rather than being added to this source import.
