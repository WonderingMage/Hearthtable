# Hearthtable Lite

This edition lives on `edition/lite`, starting with `lite-v1.0.0`. Classic Hearthtable remains on `main` and its existing `v*` releases. Do not merge the Lite product configuration into the classic branch as an ordinary update. Godot stays at 4.5.1; Lite's protocol is 11 and campaign schema remains 1. Its application name and user-data folder are **Hearthtable Lite**.

## Play contract

The DM owns the board, movement, scene changes, visibility, final sheet values, initiative order, resource spending and outcomes. Both roles use a rotatable isometric view. A DM drag measures grid distance and directly places a piece without path, collision, turn, speed or action-budget enforcement. Players may drag only assigned heroes. Outside combat there is no movement-distance cap; after the DM starts combat, the host enforces the private active turn and a cumulative speed allowance across moves. DM-set allowances support Dash and homebrew and refresh on the next turn. Player paths use revealed walkable cells, respect walls/closed doors and destination occupancy, and account for configured grid scale/diagonals/difficult terrain. Only the DM controls doors. The host rejects forged ownership, allowance/override, door, build, HP, spell-cast and combat commands.

Player interactions are their assigned sheet, dice, chat, reviewed character submissions and intentions. Checks, saves, attacks, damage, death saves and Hit Dice produce recorded dice only. Initiative requires a DM prompt for players. No dice roll automatically determines success, sorts initiative, applies damage, changes death marks or spends a resource. Movement alone spends its cumulative allowance during DM-started combat. Physical dice results can be described to the DM in an intention.

`lite_rules.gd` is the first command boundary in `World.apply_command`. It creates spell/action proposals from host-owned references and actor data. The DM's inbox shows the original 2014 rule text and a bounded candidate damage expression. Only explicit `lite_resolve` approval changes selected HP/conditions/resources; the entire decision is validated before mutation and cannot be applied twice. Temporary HP and integer half damage are simple arithmetic conveniences. Resistances, attack/save success, cover, criticals, concentration, death, durations and homebrew exceptions remain DM choices. DM placement is always free; player movement budgets follow the explicit combat controls. The DM may approve without spending or applying effects.

The classic combat modules remain as reference/shared infrastructure, but Lite blocks their automatic command routes and disables the encounter director, including door/proximity triggers. Do not re-enable automatic resolution through a new UI path or shortcut.

## Sheets

The expandable sheet covers these standard areas:

| Area | Recorded controls and information |
| --- | --- |
| Overview | Six abilities and saves; all 18 skills; proficiency/expertise/imported final bonuses; passive Perception, Investigation and Insight; initiative modifier; HP/temp HP/AC/speed; inspiration; defenses, conditions, exhaustion, Hit Dice, death records |
| Actions | Weapon attack/damage dice; grapple, shoves, Help, Dodge, Dash, Disengage, Hide, Ready, Search, object use, escape/release, opportunity attacks, bonus/reaction references and editable homebrew actions |
| Spells | Known/prepared spells, slots, casting ability, DC/attack, concentration record, full included 2014 descriptions, components/materials, time/range/duration, rituals/innate use, area, save/damage and higher levels |
| Equipment | Names, quantity, weight, equipped and attuned records, five coin types, carrying-capacity reference, imported equipment text and proposed use |
| Features | Feature/feat/racial reference text and editable limited-use counters with recharge; use is proposed to the DM |
| Description | Class/subclass/multiclass notes, ancestry/background/alignment, age/height/weight/appearance, languages/proficiencies/senses, traits/ideals/bonds/flaws and backstory |
| Notes / Extras | Personal notes, DM-shared handouts, allies/organizations/treasure, companions/familiars/mounts/vehicles and homebrew references |

PDF import retains the printed sheet and populates narrative, equipment, spell and bonus fields where supported. The existing reviewed creator and cosmetic preview remain. Imported custom spells require DM review. This is independent of D&D Beyond: no account integration, paid-book library, complete class/feat database or automatic character progression is included. Class access, multiclass slot pools, equipment effects, level-up choices and unusual resources require manual configuration. Do not claim exact D&D Beyond parity.

## Privacy

`lite.snapshot` constructs a player state from an allowlist rather than copying the campaign wholesale. A player receives full assigned sheets and visual-only revealed tokens. Other actors have neutral placeholder numeric fields solely for the existing client schema; they do not carry real health, armor, abilities, initiative, attacks, inventory, notes or spellbooks. Rendering suppresses those token health bars. Hidden actors are absent. Owned sheets remain usable off-board during blackout or concealment.

DM rolls, legacy dice/outcome logs, NPC sheets, DCs in roll prompts, initiative order, future scenes, DM journal/scene notes, private requests/decisions and other owners' sheet details are excluded. Only the owner receives their current movement permission/allowance; the enemy turn identity/order stays private. Player roll/request visibility is scoped to the current network session and assigned actor. The host can explicitly disclose text using chat, a request reply, a turn announcement or the public journal.

New props and creatures start concealed. Moving a prop preserves its flag. `lite_prop` reveals/conceals a particular object. Fogged cell data and props are removed, custom asset packs include only visible referenced designs, and imported PNG pixels are copied into a black image only for revealed cells before content-addressed transfer. A blackout sends a fixed empty placeholder scene, with no board art or asset manifests. The existing downloader rejects requests for unadvertised blobs. Previously revealed/downloaded information cannot be made unknown again; blackout controls current transfer and display.

## Custom creatures

Use **+ Custom creature**, edit a sheet, import/export a `.hearthcreature`, or add the original Ember Warden example directly from that menu. Ask Codex for a creature package using a description/reference plus size, AC, HP, abilities, attacks and traits. The package is JSON:

```json
{
  "format": 1,
  "application": "Hearthtable Lite creature",
  "actor": {
    "name": "Example guardian", "class": "Creature", "race": "Construct",
    "hp": 30, "max_hp": 30, "ac": 15, "speed": 25,
    "abilities": [16, 10, 14, 6, 12, 8], "token_size": 1,
    "weapon": "Fist", "attack": 4, "damage": "1d8+2",
    "miniature": "Custom",
    "lite_model": [{"shape":"sphere","position":[0,0.8,0],"scale":[0.7,1.2,0.7],"color":"#887766"}],
    "notes": "DM adjudicates the printed attacks and traits."
  }
}
```

`lite_creature.gd` defines the exact actor field allowlist and geometry validator. Maximum file size is 1.5 MB; models use 1–64 box/sphere/cylinder/cone/torus parts with bounded finite transforms and RGB colors. Optional `rotation` is in degrees. No scripts, shaders, packed scenes, arbitrary resource paths or native plugins are loaded. Export uses the same whitelist as import. Models and stat blocks remain inside ordinary campaign, scene and portable exports.

## Builds and tests

The first Lite installation needs **Hearthtable_Lite_Portable.exe**; do not import it into classic Hearthtable. Lite Settings accepts only `application: Hearthtable Lite` packages whose full digest matches `Hearthtable-Lite-VERSION.hearthupdate` in the published `lite-vVERSION` release. The foundation is 1.0.0. Campaign backup, restart, failed-boot fallback, rollback and portable rebaking retain the established updater design.

`tools/release_lite.py --tag lite-vVERSION --output /new/output --toolchain /optional/pinned/toolchain` builds the exact clean tag without publishing. Its exported-resource suites are `lite`, `updates`, and `pdf_import`; it also runs `tools/test_lite_network.py` with a real DM and two players, both portable creation/restoration routes, and the compiled-update lifecycle. Only `--publish --repo WonderingMage/Hearthtable` publishes. The GitHub tag workflow uses its built-in token. Attach only the plain Lite EXE, matching update, SHA256SUMS and manifest; never attach private QA/DM campaigns.

`lite_ui.gd` renders real desktop/minimum-window controls, drag/distance behavior, all sheet pages, custom model import/export, blackout and the verified Settings install/backup/offline gate. `pdf_import_ui.gd` retains reviewed-PDF interaction coverage. `tools/test_lite_network.py --ui` additionally renders the real remote player sheet, roll prompts, spell proposal and blackout. Always verify disposable `Hearthtable Lite` user data before resetting any suite; use separate data directories for each peer/process.

Native Windows launch, physical GPU/audio and external NAT/firewall play remain separate unverified work. A Linux run of Windows resources is not native Windows execution. Publish as a prerelease until those checks are performed.
