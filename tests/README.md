# Verification

Use Godot 4.5.1. Run tests against isolated user data, so they cannot replace a real campaign.

Core examples:

```
godot --headless --path . --script res://tests/magic.gd
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/combat_range.gd
godot --headless --path . --script res://tests/rooms.gd
godot --headless --path . --script res://tests/pdf_import.gd
```

Set XDG_DATA_HOME to a temporary directory on Linux; use separate OS/user data for Windows testing. These tests intentionally reset the test campaign.

Graphical tests require an OpenGL-capable display. `features_ui.gd` covers actual slot-spending through the casting UI, character pages, equipment editors, scene image/package import and custom-port DM lobby controls. Other graphical tests preserve native rendering, room/camera behavior, PDF review and attack-range coverage. Pass `-- --qa` to suppress the welcome dialog.

The casting UI fixture checks that an opening hostile spell starts initiative without spending resources, then confirms that spell on the caster's turn. Room UI checks preserve isometric pitch and use the separate Door control to close doorways. The attack-range UI suite also checks that scene loading retains the inspector's preview.

`magic_network.gd` runs in two processes: start the host with `-- --host`, then a client without that flag. It uses UDP 24705 and a test-only passphrase. Both processes must share the same network namespace. Adding `-- --ui --qa` to the client renders the real player lobby/sheet and verifies disabled host controls. The host waits for a client acknowledgement before stopping. Older networking tests use UDP 24680 and must be run separately.

Tests cover ownership, rejected-cast resource integrity, range/area-origin checks, upcasting, 2014 bonus-action restrictions, ritual/innate casts, damage/concentration, saving throws, recovery, attunement, serialization, lobby admission/ready/submission, scene-only snapshots, cached maps and disconnect cleanup.

Native Windows execution, a user's GPU/firewall and real residential NAT forwarding still require local/external testing. See the release BUILD_NOTES.txt for this build's exact results.

Version 0.7: tactical_ui.gd checks the tactical camera, click movement/path costs, target hover versus execution, hotbar casting, minimum-window layout and player ownership. For the multiplayer tactical HUD route, pass -- --host --tactical to magic_network.gd on the host and -- --ui --qa --tactical on the graphical client. The exported Windows pack can be exercised with matching Godot --main-pack Hearthtable_Portable.exe plus an external test-script path on Linux. This validates exported assets/scripts, not native Windows execution.

## Version 0.9

Current builder suites: build.gd (33 core assertions) and build_ui.gd (32 native UI/view assertions). The latter checks the new fixed views, catalog/ghosts, click placement, pickup/move/cancel, themed scenes and minimum window. magic_network.gd with --host --tactical and a graphical --ui --qa --tactical client covers actual player controls, replicated furniture and rejected build commands. Use the same protocol-9 release in both processes.

Historical first-person/following and host-tactical tests are under archive and are not current entry points; those modes were removed from the product.

## Version 0.10

director.gd verifies initiative ordering, opening weapon/spell resource integrity, cumulative movement, Dash, different speeds, walls/doors, proximity, private zones, rearming, scene import and lighting authority. director_ui.gd renders the DM enemy HUD, initiation banner/dice, map-corner zone drawing, local light and shadow caps, day/night presets and minimum-window/player views. director_network.gd runs a real UDP 24711 host/client pair (-- --host on the host) and verifies private boundaries, lighting, movement authority, opening attacks, proximity and visible dice. Existing isolated combat/magic/room fixtures explicitly disable automatic encounters to test those subsystems independently. portable.gd also checks embedded zone and lighting restoration.

## Version 0.11

prepared.gd imports both supplied map packages, verifies calibrated routes and batched native designs, checks double-gate/large-creature traversal, imported-design reuse and malformed-pack rejection. maps_ui.gd renders both maps and exercises actual closed/open doorway click handling. maps_network.gd uses a host/client pair on UDP 24720; pass -- --host to the host, and optionally -- --ui --qa to a graphical client. It verifies cold-download progress, custom art/assets, door traversal, private-data exclusion, scene changes, cache return and reconnect from the disk cache. Portable snapshot tests include a reusable imported design. Run each suite with isolated user data.

`maps_network.gd` acknowledges initial scene validation separately from the rendered gate walkthrough. Its client waits for transport/authority state have 30-second wall-clock deadlines; host acknowledgements that include rendering and screenshots have a 120-second budget for software OpenGL. A timeout reports its stage, fails the process and stops the scenario rather than switching scenes after a failed prerequisite. Allow at least 600 seconds for an outer graphical-pair runner timeout; run pairs serially. These are functional checks, not a network or rendering performance benchmark.

## Portable snapshot validation

Use `portable.gd` to create a synthetic campaign copy from an exported program, passing `-- --source=/absolute/path/plain-program --destination=/absolute/path/new-copy`. Launch the resulting native executable with an external absolute test-script path and `-- --verify` to check restoration. Always use fresh isolated user data for each process.

To inspect a Windows campaign copy using the matching Linux **editor** instead, specify both the engine pack and the editor-only snapshot source:

```sh
# Linux only; set XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME to disposable directories first.
godot --headless --main-pack /absolute/path/campaign.exe --script /absolute/path/tests/portable.gd -- --verify --portable-source=/absolute/path/campaign.exe
```

Godot consumes `--main-pack` before exposing engine arguments to application scripts. `--portable-source` supplies the appended snapshot to the editor explicitly. Exported programs ignore that override and always inspect their own executable. Testing Windows resources and embedded snapshots with Linux does not establish native Windows launch, GPU or firewall behavior.

## Character/action development (protocol 10)

`actions.gd` covers original-2014 grapple/shove contests and ties, Extra Attack budgets, size/reach/free hands, failed attempts, escape/release, dragging, opening initiative, Help consumption/expiry, spell Help, Dodge speed-zero expiry, and hostile/malformed cosmetic commands. `creator_ui.gd` exercises the actual shared creator, imported sheet review, draft cancellation, actual 3D props, palette updates, persistent cosmetics, save/load, minimum-window footer and action targeting. `pdf_import_ui.gd` verifies imported bonus retention and undo through the shared review flow.

`actions_network.gd` uses UDP 24727: host with `-- --host`, client without it (or `-- --ui --qa` for the actual player creator and tactical targeting). It checks pending character submissions, DM acceptance, owner-only cosmetics, unchanged stats, invalid model rejection, hidden/private data filtering, grapple resources, free off-turn release, Help and replicated miniatures. Run fixed-port suites serially. `portable.gd` additionally verifies created identity and appearance after restoring an embedded campaign.

Cloud helpers support `python3 /workspace/hearthtable-toolchain/check.py headless --suite actions`, `ui --suite creator_ui`, `network --suite actions_network`, and `network-ui --suite actions_network`. They retain the existing proven disposable user-data isolation. These are Linux/matching-pack checks, not native Windows validation.

## Application updates and ornate UI (0.12)

`updates.gd` validates package parsing, supported pack/engine/manifest bounds, fixed-release digest provenance, tamper and downgrade rejection, pending state, startup confirmation, failed-start/corruption rollback, duplicate imports, active-code selection during staging, and byte-for-byte campaign preservation. It uses synthetic metadata directly at the verification boundary; the product UI always fetches metadata from the fixed HTTPS GitHub origin.

`ornate_ui.gd` checks the actual desktop, Settings entry, update review/verification/install controls, offline-session gate, complete pre-update backup, character preview, expanded HUD and minimum window. Screenshots remain in disposable user data. `icons.gd` checks the dedicated illustrations for the added combat actions.

`tools/test_updates.py --engine /path/to/godot --program /path/to/exported-linux-program --templates /path/to/export_templates --output /new/disposable/folder` creates a synthetic updated full pack in a disposable project copy. It launches the real exported program through install, restart with changed compiled World code, updated portable campaign export, transfer to fresh user data, rollback and restart into base code. Every process has a proven disposable user-data path. The release builder runs this test and retains its separate logs; no synthetic update or campaign is uploaded.

The `.hearthupdate` player artifact is produced from the exact clean release resources. It is distinct from test fixtures, private campaigns and rollback backups. Native Windows execution remains unverified; do not substitute Linux XDG settings for Windows isolation.
