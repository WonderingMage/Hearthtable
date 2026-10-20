# Lite action behavior

On `edition/lite`, these 2014 actions are reference text and player intentions. Dice do not resolve contests, hits, saves, effects or resources automatically; the DM approves outcomes in the inbox. Player movement is the board exception: unlimited distance during exploration, cumulative own-turn allowance in DM-started combat, with doors controlled only by the DM. See `docs/lite.md`. The implementation notes below describe classic 0.12.0 and are retained for its shared reference modules, not as Lite's active combat contract.

# Character and action development

Included in version `0.12.0`, protocol 10, save schema 1. The earlier v0.11.1 release uses protocol 9. Publish subsequent releases only when the owner requests one.

## Using the character menu

- **DM:** New hero opens the creator. A class starting loadout is an explicit reset of the mechanical sections to level 1; identity and cosmetics survive that reset.
- **Player:** Session → Create my character or Import my Beyond character PDF. The reviewed draft is submitted to the host; it becomes a hero only after DM acceptance, owned by the submitting peer.
- **Import:** The same Identity, Attributes, Skills, Equipment, Magic, Miniature and Review tabs show imported values. Final printed skill/save bonuses, attacks, coins, spells/preparation marks, custom spell definitions and source notes are retained. Missing spell lists do not acquire starter spells. Review warnings and confirm the draft before adding it. Canceling never creates a character.
- **Customization:** Character sidebar or full sheet → Customize miniature. Four body styles, clothing/cloak/head/base colors, supported headwear/cloak, per-style weapon/shield props, visual height/build and a rotatable preview. Preview and board share model configuration. Cosmetics persist through ordinary saves, host snapshots and portable campaign copies. Owners may customize their heroes, including in the lobby. This command accepts no mechanical sheet edits.

Class levels, race traits, background features, equipment, spells known and multiclass resource pools remain DM-reviewed final values. This is a detailed sheet editor, not a full automatic character progression or paid-book library. Changing level, class, race or abilities does not silently recalculate AC, HP, weapon damage or imported totals. Turn off imported final bonuses to use calculated ability/training values.

## Actions

The Actions hotbar has Grapple, Shove prone, Shove push and Help attack cards. Scroll to reach additional cards. Select a card and click a creature, or confirm the selected target. **More actions** / the Character sidebar's **Combat actions** dialog also provides skill Help, escape and release. Dodge, Dash, Disengage and Stand remain available.

| Action | Cost | Host resolution |
| --- | --- | --- |
| Grapple | One Attack-action attack | Clear 5-ft reach, no more than one size larger, a free hand; STR (Athletics) versus defender's better Athletics/Acrobatics. Applies a source-linked Grappled condition, speed 0. |
| Shove prone / push | One Attack-action attack | Same size/reach/contest rules. Knock prone, or move exactly 5 ft directly away into a clear, level, unoccupied location. No damage. |
| Escape grapple | One full action | Escapee's better Athletics/Acrobatics versus that grappler's Athletics. A failed attempt spends the action. |
| Release grapple | Free, also off-turn | Remove this source's hold, leaving other holds/manual conditions intact. |
| Help attack | One action | Enemy within a clear 5 ft; first eligible allied weapon/spell attack gains advantage before helper's next turn. Preview does not consume it; a miss does. Multiple sources do not grant extra assisted attacks. |
| Help check | One action | Next selected skill check for the ally gains advantage before helper's next turn. Other checks and saves do not consume it. DM confirms task eligibility and positioning. |
| Dodge | One action | Until next turn: disadvantage on attacks the dodger can see, advantage on DEX saves. Speed 0 or incapacitation ends benefits permanently for that Dodge. |

Valid failed contests spend their resource; invalid requests roll no dice and spend nothing. Ties preserve the existing situation. Imported final skill bonuses, supported Rage/Poisoned/Help/Guidance modifiers and chosen roll mode apply. The defender automatically chooses the better final bonus; unusual modifiers or alternative rulings need DM adjustment. Monster Multiattack components cannot be substituted. Opening hostile grapple/shove declarations roll initiative first and require a fresh attempt on the correct turn.

DM **Edit sheet** sets creature size and hands available for grappling after equipment is readied/stowed. Small and Medium both occupy one grid cell but remain different size categories. Each hold requires a hand. Holds end on escape, release, grappler incapacitation, death/removal or separation beyond clear reach. Ordinary movement drags held creatures along the same clear, level route, at half speed unless each held creature is at least two size categories smaller. Dragging obeys cumulative movement budgets and refuses blocked routes. Specialized repositioning, ledges, unsafe terrain, unusual grid scales, special limbs/reach, chained grapples and class exceptions need DM adjudication. Walking into a wall or an occupied destination is never substituted for a successful push.

Opportunity attacks, Ready/Hide/Search adjudication, source-specific frightened/sight modifiers and other rules outside the existing automation coverage remain manual. This work does not add 2024 grapple saving throws or BG3 combat rules.

## Implementation and checks

- `combat_actions.gd`: host-only mutation/contests, source-linked effects and lifecycle, dragging, Help, Dodge eligibility.
- `character_creator.gd`: isolated draft; shared creation/import/review; separate owner-only cosmetic save.
- `mini_appearance.gd`: bounded cosmetic schema and bundled-model mesh/material configuration. No imported paths or scripts.
- `world.gd`: dedicated owner-checked cosmetic command; private identity details follow existing owner filtering. Protocol 10 rejects mixed older clients; optional actor fields preserve schema-1 saves.
- `actions.gd`, `creator_ui.gd`, updated PDF UI suite, `actions_network.gd` (UDP 24727), and portable restoration exercise the new behavior. Existing core/UI/network suites remain regression checks. `tools/release.py` includes the new action suite for future requested release builds.

Linux uses the retained official Godot 4.5.1 and proven disposable `user://` probes in the cloud runner. Native Windows execution, hardware/audio and external internet sessions remain separate validation; none is implied by matching Linux tests of the Windows exported resources. Do not run resetting tests against live campaigns.
