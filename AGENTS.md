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
