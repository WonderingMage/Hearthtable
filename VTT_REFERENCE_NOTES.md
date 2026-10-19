# VTT implementation references for Hearthtable 0.2

The requested review used actual source files, rather than screenshots or a study-guide layout. These were inspected as design and engineering references. Hearthtable's Godot implementation is original; no source from these VTTs was copied into the runtime.

## PlanarAlly

Repository: https://github.com/Kruptein/PlanarAlly
Reviewed revision: c9146b233102027db11c6aa7d22f962105798c2a

Files inspected:

- client/src/game/tools/variants/ruler.ts
- client/src/game/rendering/grid.ts
- client/src/game/layers/variants/grid.ts
- client/src/game/ui/tools/RulerTool.vue
- client/src/game/interfaces/layers/grid.ts

The ruler distinguishes free-distance and snapped-grid measurements, derives distances from the configured unit size, formats units separately from cells, and highlights measured cells without adding permanent scene objects for every mouse move.

Applied in Hearthtable: scene-specific square distance/units, separate grid and Euclidean metrics, native overlay ruler labels and temporary highlighted movement cells. Persistent templates and fog remain separate scene state.

## RPTools MapTool

Repository: https://github.com/RPTools/maptool
Reviewed revision: c36a06154c5c528c36dea23bcd310fdb1fed24d5

Files inspected:

- src/main/java/net/rptools/maptool/model/SquareGrid.java
- src/main/java/net/rptools/maptool/client/ui/zone/renderer/ZoneRenderer.java

The grid separates screen/map coordinate conversion from logical cells, accounts for offsets and cell centers, provides square-grid snapping, and supports alphabetic coordinate labels. The renderer provides a separate workspace for tokens, grid, map and interaction layers.

Applied in Hearthtable: independent logical grid coordinates and screen/world projection, snapping to miniature footprints, column/row references, image-to-grid calibration, a camera-independent unit scale, and separate 3D terrain / miniature / native overlay layers. MapTool's Java implementation is not included or translated.

## The Forge's public integration module

Repository: https://github.com/ForgeVTT/fvtt-module-forge-vtt
Reviewed revision: 4f9d5f75ec303aa1585e5413aa2579a6583c1f81

Files inspected:

- src/ForgeVTT.mjs
- src/applications/ForgeVTTFilePicker.mjs
- public/module.json
- README.md

This is Forge's public Foundry integration module. The review covered the integration setup, asset source/file-picker behavior and permission-aware upload entry points. It does not constitute access to Forge's hosting backend or Foundry's proprietary core source.

Applied in Hearthtable: clearly separated scene/actor tools, a controlled asset-import workflow, and host-only changes for scene resources. The executable remains an independent local/private-session VTT; it does not connect to Forge services or import licensed Foundry packages.

## Rendering and assets

Godot documentation reviewed:

- https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html
- https://docs.godotengine.org/en/4.5/tutorials/3d/3d_antialiasing.html

Hearthtable uses a native-resolution interface, an independently sized 3D render buffer that accounts for UI scale, orthographic cameras and user-selectable MSAA. Imported maps preserve source detail up to the stated image limit and use mipmapped anisotropic filtering when viewed obliquely.

Dungeon props and orc figure: Kenney Mini Dungeon 2.0, CC0.
https://kenney.nl/assets/mini-dungeon

Inter interface typeface: SIL Open Font License.
https://github.com/google/fonts/tree/main/ofl/inter

Animated fantasy adventurer miniatures: KayKit Character Pack: Adventurers 1.0,
CC0, by Kay Lousberg. Official source:
https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
Character GLBs were optimized to retain four animations and their required
buffers. The original rigs, textures and body geometry are retained. Equipment
visibility is configured for the selected visual archetype at runtime.

KayKit source revision: 672074b73ba276876a19e8816ecdc5241817ab47.


## 0.4 combat-rule verification

Range, grid distances, occupied space, ranged-close-combat disadvantage, reach, cover, advantage/disadvantage and attack conditions were checked against the original 2014 Basic Rules and included SRD 5.1. Official source: https://www.dndbeyond.com/sources/dnd/basic-rules-2014/combat (reviewed 2026-10-19). Standard weapon ranges use the 2014 SRD equipment table. Monster reach/range is parsed from the bundled 2014 SRD stat blocks, rather than inferred from size. The implementation is original Godot code.
