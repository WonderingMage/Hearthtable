# Hearthtable

An editable Godot **4.5.1** virtual tabletop for original **2014 D&D 5e**. The current version is **0.11.1**, campaign schema **1**, multiplayer protocol **9**.

The repository root is the Godot project directory: open `project.godot` here. The complete source is in `scripts/`, `assets/`, `tests/`, `art/` and `tools/`; there is no additional `Source` wrapper in this checkout.

## Start development

1. Read `AGENTS.md`, `CODEX_HANDOFF.md` and `Hearthtable_Codex_Workflow.md`.
2. Install Godot 4.5.1 standard and matching export templates when building a release.
3. Import/open this directory in Godot, or run `godot --editor --path .` with the correct editor on PATH.
4. Use `tests/README.md` for the test suites and `assets/help/automation.txt` for the actual rules coverage and limitations.

Tests intentionally reset their campaign. Use isolated user data; never use real campaign saves as fixtures. On Linux, set `XDG_DATA_HOME` to a fresh disposable directory for each test process. Native Windows needs a verified Windows isolation method, as described in the workflow guide.

The Windows export preset embeds the engine/game pack in a single executable. Generated programs, caches, personal characters and campaign snapshots do not belong in source commits. Native Windows launch and external port-forwarded play remain separate validation tasks.

Releases attach `Hearthtable_Portable.exe` directly for a one-file player download. New releases are published only on request; see `docs/releases.md`.

## Source and notices

Missing source directories were restored from the complete Hearthtable 0.11 source companion. `SOURCE_RESTORATION.md` records provenance and the scope of this import. Original application source licensing is included in `LICENSE.txt`; third-party attribution is in `THIRD_PARTY_NOTICES.txt`, `Reference/` and the asset directories. The existing repository `LICENSE` is retained unchanged.

No campaign saves, imported character PDFs, generated executables or Godot cache files are included. Prepared map images are embedded in their scene JSON assets. Public reference PDFs remain available through the links in the notices rather than being added to this source import.
