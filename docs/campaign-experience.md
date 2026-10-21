# Campaign experience brief

The owner wants a streamlined, detailed **multiplayer 2014 5e homebrew table**.
The improvement loop builds missing capabilities as well as fixing bugs. Use
D&D Beyond's familiar sheet organization and terminology as a usability
reference: Overview, Actions, Bonus Actions, Reactions, Spells, Equipment,
Features & Traits, Conditions and resources. Preserve Hearthtable's DM-led
board, PDF import review and adjustable homebrew values. This is an independent
application; Beyond account integration and paid-book content are not implied.

## First priority: Druid becomes a Dire Wolf

An approved Wild Shape should produce a usable transformed sheet, not leave the
player reading the original humanoid numbers. Inspect the current local branch
before implementing: its app commits may be newer than the cloud checkout.
The cloud source at this brief's introduction has a Wild Shape use counter in
`scripts/magic.gd`; no end-to-end transformation implementation was found by
source search. That is an implementation lead, not a claim of runtime testing.

Use `Reference/SRD_5.1_2014.pdf` when present, or the official CC-licensed 5.1
reference linked in `assets/help/licenses.txt` (Druid/Wild Shape, beasts and Dire
Wolf), plus `assets/monsters.json` and existing attribution. The reference PDF
is not tracked in this cloud checkout; do not claim to have read a missing file.
Check subclass, druid level, beast CR, movement restrictions and known forms;
a 2014 non-Moon druid
cannot assume a CR 1 Dire Wolf at level 2. Circle of the Moon and explicit DM
homebrew exceptions must be distinguishable. Wild Shape is a class feature,
not spell-slot casting. Do not apply Polymorph's different rules to Wild Shape.

Work toward this complete journey:

1. Player proposes a form with a readable before/after preview. The DM reviews
   eligibility, feature uses, duration, gear treatment and any homebrew override.
   Decline/cancel spends nothing and changes no sheet. The DM may configure an
   allowed custom beast using bounded data; never execute imported code.
2. DM approval changes the authoritative effective sheet. Show form name,
   physical abilities, beast AC/HP/Hit Dice, size, movement, attacks, senses and
   traits. Retain the appropriate mental abilities, identity, proficiencies and
   eligible features under the 2014 rules; compare relevant beast/character
   proficiency bonuses correctly. Explain unavailable equipment and spellcasting
   clearly instead of leaving active humanoid controls with misleading numbers.
3. Preserve base-form data separately. Track beast HP, original HP and temp HP
   according to the reference. Concentration does not automatically end on Wild
   Shape; qualified existing spell actions can differ from casting new spells.
   Present prompts for DM decisions rather than deciding outcomes automatically.
4. DM-controlled reversion restores the base sheet and cosmetic miniature.
   Handle the 2014 zero-HP/excess-damage rules through an explicit reviewed DM
   transition. Account for duration, unconsciousness/death and voluntary ending
   without silently losing damage, conditions, resources or the original sheet.
5. Save/load, undo where supported, reconnect and repeated transformations must
   preserve both forms correctly. The owner sees their effective sheet; other
   players see only permitted token visuals, with hidden/blackout rules intact.
   Players cannot approve their own forms, edit another hero or spoof beast data.

These are acceptance goals, not features claimed to exist today. Deliver one
coherent, tested slice per cycle. Keep unfinished mechanics clearly unavailable;
do not ship a form button that promises working transformed stats prematurely.

## Keep exploring the whole table

Use the following as a rotation of synthetic play scenarios, not as a claim of
rules coverage. Each cycle audits at least one class situation and one shared
interaction, then chooses the most useful bounded improvement. Check the latest
coverage notes and Git history before repeating an area. If an earlier area
still blocks play, finishing it can take priority over rotation.

| Class | Campaign situations to exercise |
| --- | --- |
| Druid | Wild Shape, separate form HP, reversion, concentration, form restrictions |
| Barbarian | Rage uses/duration, resistances presented for DM decisions, Reckless Attack |
| Bard | Inspiration recipients/dice, expiry, short-rest recovery and concentration |
| Cleric | Channel Divinity, prepared spells, concentration, healing and death saves |
| Fighter | Second Wind, Action Surge, Extra Attack information, limited-use recovery |
| Monk | Ki costs, Martial Arts, movement changes, bonus actions and reactions |
| Paladin | Lay on Hands pool, Divine Smite proposal, auras and concentration |
| Ranger | Favored terrain/enemy references, Hunter's Mark, ammunition and companions |
| Rogue | Sneak Attack eligibility information, Cunning Action and reaction timing |
| Sorcerer | Sorcery points, slot conversion, Metamagic proposals and resource clarity |
| Warlock | Pact Magic vs ordinary slots, short rests, invocations and concentration |
| Wizard | Prepared vs known spells, ritual casting, Arcane Recovery and reactions |

Shared situations include exploration into combat, own-turn movement after
speed/form changes, difficult terrain, grapple/shove/escape, Help/Dodge/Ready,
opportunity-attack proposals, conditions, temporary HP, death saves/revival,
short/long rests, carrying/equipped/attuned items, spell components and targeting,
multiclass resource pools, companions/summons and explicit homebrew exceptions.
Exercise a dungeon fight, travel, a social scene and returning after a saved
session over successive cycles. Public play examples can inspire scenarios if
actually inspected and cited; do not invent campaign experience or use private
campaigns/PDFs as fixtures.

## Evidence and remaining work

Builder updates this section only alongside an accepted application change;
Tester and Critic independently verify the stated result. Record the scenario,
rule/reference used, what now works, actual test/screenshot/report evidence and
the next missing slice. Label **verified**, **partial**, **manual only** or
**not verified**; a passing unrelated suite is not proof of feature support.
Do not commit local report paths containing private user information. Reports
can retain detailed paths privately. Leave this file unchanged on no_change.

- **Not verified — Wild Shape to Dire Wolf:** first priority; the source search
  found a resource counter but no full form-state workflow. No runtime coverage
  or transformed-sheet support is claimed by this tooling change.
- **Not verified — remaining class/scenario matrix:** future cycles must inspect
  the actual current application and record evidence rather than assume that
  a generic feature counter implements each feature's full play experience.
