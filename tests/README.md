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
