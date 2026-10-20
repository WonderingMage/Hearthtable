extends RefCounted
## Structured 2014/SRD choices. Imported and homebrew values remain selectable.
const CLASSES={
	"Barbarian":{"role":"A tough front-line warrior, powered by Rage.","primary":"STR, CON","subclass":"Path of the Berserker","subclass_level":3,"skills":2,"armor":"Unarmored","shield":false},
	"Bard":{"role":"An inspiring performer with versatile skills and magic.","primary":"CHA, DEX","subclass":"College of Lore","subclass_level":3,"skills":3,"armor":"Leather","shield":false},
	"Cleric":{"role":"A divine spellcaster who supports allies and fights in armor.","primary":"WIS, CON","subclass":"Life Domain","subclass_level":1,"skills":2,"armor":"Chain mail","shield":true},
	"Druid":{"role":"A nature spellcaster; Wild Shape starts at level 2.","primary":"WIS, CON","subclass":"Circle of the Land","subclass_level":2,"skills":2,"armor":"Leather","shield":true},
	"Fighter":{"role":"A trained weapon specialist with durable armor.","primary":"STR or DEX, CON","subclass":"Champion","subclass_level":3,"skills":2,"armor":"Chain mail","shield":true},
	"Monk":{"role":"A mobile martial artist who fights without armor.","primary":"DEX, WIS","subclass":"Way of the Open Hand","subclass_level":3,"skills":2,"armor":"Unarmored","shield":false},
	"Paladin":{"role":"An armored warrior with divine powers; spellcasting starts at level 2.","primary":"STR, CHA","subclass":"Oath of Devotion","subclass_level":3,"skills":2,"armor":"Chain mail","shield":true},
	"Ranger":{"role":"A wilderness warrior; spellcasting starts at level 2.","primary":"DEX, WIS","subclass":"Hunter","subclass_level":3,"skills":3,"armor":"Leather","shield":false},
	"Rogue":{"role":"A precise attacker with Sneak Attack and expert skills.","primary":"DEX","subclass":"Thief","subclass_level":3,"skills":4,"armor":"Leather","shield":false},
	"Sorcerer":{"role":"An innate arcane spellcaster with a small, flexible spell list.","primary":"CHA, CON","subclass":"Draconic Bloodline","subclass_level":1,"skills":2,"armor":"Unarmored","shield":false},
	"Warlock":{"role":"A pact-bound caster with short-rest Pact Magic.","primary":"CHA, CON","subclass":"The Fiend","subclass_level":1,"skills":2,"armor":"Leather","shield":false},
	"Wizard":{"role":"A scholarly arcane caster who prepares spells from a spellbook.","primary":"INT, CON","subclass":"School of Evocation","subclass_level":2,"skills":2,"armor":"Unarmored","shield":false}
}
const ANCESTRIES={
	"Human":{"variants":["Human"],"bonus":[1,1,1,1,1,1],"speed":30,"size":"Medium","languages":["Common"]},
	"Dwarf":{"variants":["Hill Dwarf"],"bonus":[0,0,2,0,1,0],"speed":25,"size":"Medium","languages":["Common","Dwarvish"]},
	"Elf":{"variants":["High Elf"],"bonus":[0,2,0,1,0,0],"speed":30,"size":"Medium","languages":["Common","Elvish"]},
	"Halfling":{"variants":["Lightfoot Halfling"],"bonus":[0,2,0,0,0,1],"speed":25,"size":"Small","languages":["Common","Halfling"]},
	"Dragonborn":{"variants":["Dragonborn"],"bonus":[2,0,0,0,0,1],"speed":30,"size":"Medium","languages":["Common","Draconic"]},
	"Gnome":{"variants":["Rock Gnome"],"bonus":[0,0,1,2,0,0],"speed":25,"size":"Small","languages":["Common","Gnomish"]},
	"Half-Elf":{"variants":["Half-Elf"],"bonus":[0,0,0,0,0,2],"speed":30,"size":"Medium","languages":["Common","Elvish"]},
	"Half-Orc":{"variants":["Half-Orc"],"bonus":[2,0,1,0,0,0],"speed":30,"size":"Medium","languages":["Common","Orc"]},
	"Tiefling":{"variants":["Tiefling"],"bonus":[0,0,0,1,0,2],"speed":30,"size":"Medium","languages":["Common","Infernal"]}
}
const BACKGROUNDS=["Acolyte","Charlatan","Criminal","Entertainer","Folk Hero","Guild Artisan","Hermit","Noble","Outlander","Sage","Sailor","Soldier","Urchin"]
const BACKGROUND_SKILLS={"Acolyte":["Insight","Religion"],"Charlatan":["Deception","Sleight of Hand"],"Criminal":["Deception","Stealth"],"Entertainer":["Acrobatics","Performance"],"Folk Hero":["Animal Handling","Survival"],"Guild Artisan":["Insight","Persuasion"],"Hermit":["Medicine","Religion"],"Noble":["History","Persuasion"],"Outlander":["Athletics","Survival"],"Sage":["Arcana","History"],"Sailor":["Athletics","Perception"],"Soldier":["Athletics","Intimidation"],"Urchin":["Sleight of Hand","Stealth"]}
const ALIGNMENTS=["Lawful Good","Neutral Good","Chaotic Good","Lawful Neutral","True Neutral","Chaotic Neutral","Lawful Evil","Neutral Evil","Chaotic Evil","Unaligned"]
const LANGUAGES=["Common","Dwarvish","Elvish","Giant","Gnomish","Goblin","Halfling","Orc","Abyssal","Celestial","Draconic","Deep Speech","Infernal","Primordial","Sylvan","Undercommon","Druidic","Thieves' Cant"]
const WEAPONS={
	"Club":["1d4",false,false,5,0,0,2],"Dagger":["1d4",true,false,5,20,60,1],"Greatclub":["1d8",false,false,5,0,0,10],"Handaxe":["1d6",false,false,5,20,60,2],"Javelin":["1d6",false,false,5,30,120,2],"Light hammer":["1d4",false,false,5,20,60,2],"Mace":["1d6",false,false,5,0,0,4],"Quarterstaff":["1d6",false,false,5,0,0,4],"Sickle":["1d4",false,false,5,0,0,2],"Spear":["1d6",false,false,5,20,60,3],
	"Light crossbow":["1d8",false,true,5,80,320,5],"Dart":["1d4",true,true,5,20,60,.25],"Shortbow":["1d6",false,true,5,80,320,2],"Sling":["1d4",false,true,5,30,120,0],
	"Battleaxe":["1d8",false,false,5,0,0,4],"Flail":["1d8",false,false,5,0,0,2],"Glaive":["1d10",false,false,10,0,0,6],"Greataxe":["1d12",false,false,5,0,0,7],"Greatsword":["2d6",false,false,5,0,0,6],"Halberd":["1d10",false,false,10,0,0,6],"Lance":["1d12",false,false,10,0,0,6],"Longsword":["1d8",false,false,5,0,0,3],"Maul":["2d6",false,false,5,0,0,10],"Morningstar":["1d8",false,false,5,0,0,4],"Pike":["1d10",false,false,10,0,0,18],"Rapier":["1d8",true,false,5,0,0,2],"Scimitar":["1d6",true,false,5,0,0,3],"Shortsword":["1d6",true,false,5,0,0,2],"Trident":["1d6",false,false,5,20,60,4],"War pick":["1d8",false,false,5,0,0,2],"Warhammer":["1d8",false,false,5,0,0,2],"Whip":["1d4",true,false,10,0,0,3],
	"Blowgun":["1",false,true,5,25,100,1],"Hand crossbow":["1d6",false,true,5,30,120,3],"Heavy crossbow":["1d10",false,true,5,100,400,18],"Longbow":["1d8",false,true,5,150,600,2],"Net":["0",false,true,5,5,15,3]
}
const ARMOR={"Unarmored":[10,-1,0],"Padded":[11,-1,8],"Leather":[11,-1,10],"Studded leather":[12,-1,13],"Hide":[12,2,12],"Chain shirt":[13,2,20],"Scale mail":[14,2,45],"Breastplate":[14,2,20],"Half plate":[15,2,40],"Ring mail":[14,0,40],"Chain mail":[16,0,55],"Splint":[17,0,60],"Plate":[18,0,65]}
const PACKS=["Burglar's pack","Diplomat's pack","Dungeoneer's pack","Entertainer's pack","Explorer's pack","Priest's pack","Scholar's pack"]
const GEAR={"Backpack":5,"Bedroll":7,"Blanket":3,"Book":5,"Candle":0,"Climber's kit":12,"Component pouch":2,"Crowbar":5,"Healer's kit":3,"Holy symbol":1,"Hunting trap":25,"Ink":0,"Ink pen":0,"Lantern, hooded":2,"Mess kit":1,"Mirror, steel":.5,"Oil (flask)":1,"Parchment":0,"Potion of healing":.5,"Rations (1 day)":2,"Rope, hempen (50 ft)":10,"Spellbook":3,"Tinderbox":1,"Torch":1,"Waterskin":5,"Arrows (20)":1,"Crossbow bolts (20)":1.5,"Shield":6,"Thieves' tools":1,"Herbalism kit":3,"Disguise kit":3,"Lute":2,"Flute":1}
const ARRAY=[15,14,13,12,10,8]
static func ancestry_for(race: String) -> String:
	for key in ANCESTRIES:
		if key==race or ANCESTRIES[key].variants.has(race):return key
	return ""
static func point_cost(score: int) -> int:return {8:0,9:1,10:2,11:3,12:4,13:5,14:7,15:9}.get(score,99)
static func item(name: String) -> Dictionary:
	var weight=WEAPONS[name][6] if WEAPONS.has(name) else ARMOR[name][2] if ARMOR.has(name) else GEAR.get(name,0)
	return {"name":name,"quantity":1,"weight":float(weight),"equipped":false,"attuned":false,"notes":""}
