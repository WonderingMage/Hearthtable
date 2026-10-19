# Original Hearthtable artwork

`build_regalia.py` regenerates the semantic spell/weapon illustrations, action and class medallions, icon catalog, and gilded nine-slice material textures using only Python's standard library. Run it from any directory. It resolves the project's assets folder relative to itself.

All 319 included 2014 SRD spells have dedicated semantic vector compositions. The weapon set includes the 37 standard weapons and unarmed, with extra creature attack anatomy. The glyphs use effect/weapon silhouettes, complementary detail and fixed constellations. No BG3 image or UI asset is used.

The Godot `icon_library.gd` shares these assets across controls, resolves common imported weapon names, caches textures and generates stable sigils for custom entries. The source SVGs use a 128-unit drawing grid rasterized at 256px by Godot. Names/tooltips and shortcut badges remain independent of the artwork.

Run `tests/icons.gd` through Godot to audit the full catalog and write decoded preview PNGs to its isolated user-data folder. `tests/tactical_ui.gd` also checks actual pointer input through an illustrated hotbar slot, theme resources and small-window layout. Keep real campaigns separate from test user data.

The original artwork and generator use Hearthtable's MIT license. The embedded unmodified DejaVu Serif font has its own included license under assets/help/dejavu_license.txt.
