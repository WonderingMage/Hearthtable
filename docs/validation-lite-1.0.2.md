# Lite 1.0.2 prepared build

Application source: `7cde9255d14c2a05240ac8a3dd83efed18403611`, branch `edition/lite`, Godot 4.5.1, protocol 11/schema 1. This is a **validation build**, not a published release. No `lite-v1.0.2` tag or release was created; the publication step was skipped. Latest published Lite remains 1.0.1.

[Successful Linux/Windows build run](https://github.com/WonderingMage/Hearthtable/actions/runs/39531379652) · [Windows review artifact](https://github.com/WonderingMage/Hearthtable/actions/runs/39531379652/artifacts/12315159166)

The artifact (about 73.4 MB, retained for 14 days) contains the primary installer ZIP, matching Settings update, checksums and manifest. Downloading Actions artifacts may require a GitHub login. Extract the artifact, then extract `Hearthtable-Lite-1.0.2-Windows.zip` and run its setup EXE. Settings installation requires a published matching release for provenance verification; this unpublished update is prepared for that future release.

Installer ZIP: **53,134,620 bytes**, SHA-256 `99dc05eb3ced2e15e5a0bdd179e72716cb5d241153c8781c69401c4fc1b0e78a`.

- Clean CI exports and application checks passed: 94 Lite, 31 updates, 29 PDF, 37 actual three-process network, 24 Windows/Linux portable creation/restoration, 15 compiled-update lifecycle assertions: **230 total**. The prior local source checkpoint also passed the same 230 checks.
- Exported Windows resources from this final source passed **79 rendered assertions** under matching Linux Godot/software OpenGL: 44 DM/player/sheet/update UI, 13 PDF interaction, 22 full-sheet review/equipment/preparation/cosmetics/notification/eraser/throne-button checks. Screens were inspected at 1600×1000 and 1200×760.
- Native Windows installed app passed **12 headless assertions**: actual throne image present and the small-ID import works offline, in a hosted lobby, and at a hosted table, without command-size rejection.
- Native Windows setup validated Program Files (x86), exact installed payload, versioned editable source/notices, desktop/Start Menu shortcuts and targets, uninstall removal, and AppData preservation. QA refused any existing app/user data and ran only on a fresh GitHub-hosted VM.

The earlier actual published 1.0.1 Windows EXE also passed its separate full-payload diagnostic (run `39528691527`). That did not reproduce the owner's environment. The new Add-to-library button avoids transporting the 4.4 MB map by loading a hardcoded catalog ID locally instead.

No signing identity is configured: **the test app/setup are unsigned**. Authenticode hooks are prepared, but trusted signing and timestamp verification with a real identity are not validated yet. See [Windows installation/signing](windows-installation.md) for the free SignPath application route and required owner input. Physical Windows GPU/audio, SmartScreen reputation and external residential internet play remain untested.

These assets contain plain application/source data, not private campaigns, PDFs or QA logs. A future requested release must tag the intended clean source and rebuild through both stages; never replace the already published 1.0.1 assets.
