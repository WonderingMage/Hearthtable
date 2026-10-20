extends RefCounted
const PDF=preload("res://scripts/pdf_sheet.gd")
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/combat_rules.gd")

static func normalized(value: String) -> String:
	return value.to_lower().replace(" ","").replace("_","").replace("&","").replace("-","")

static func first(fields: Dictionary,names: Array,default: String="") -> String:
	for name in names:
		if fields.has(normalized(name)):return str(fields[normalized(name)])
	return default

static func integer(value: String,default: int=0) -> int:
	var regex=RegEx.new();regex.compile("[+-]?[0-9]+")
	var found=regex.search(value.replace("−","-"))
	return int(found.get_string()) if found else default

static func read(path: String,loadouts: Dictionary) -> Dictionary:
	var parsed=PDF.new().read(path)
	if not parsed.ok:return parsed
	var result=from_fields(parsed.fields,loadouts,path.get_file())
	if result.ok and not parsed.conflicts.is_empty():result.issues.append("This PDF has conflicting duplicate fields: "+", ".join(parsed.conflicts)+". The first value was used; verify it before adding the hero.")
	return result

static func from_fields(raw: Dictionary,loadouts: Dictionary,filename: String="character.pdf") -> Dictionary:
	var fields={}
	for key in raw:
		var value=str(raw[key]).strip_edges()
		if not value.is_empty() and value!="Off" and not fields.has(normalized(key)):fields[normalized(key)]=value
	var name=first(fields,["CharacterName","CharacterName2","CharacterName4"])
	if name.is_empty():return {"ok":false,"error":"Character name not found. Use the original filled D&D Beyond Export to PDF sheet."}
	var issues=[];var class_text=first(fields,["CLASS LEVEL","ClassLevel","Class and Level"]);var primary_class="";var level=0
	var regex=RegEx.new();regex.compile("(?i)(Barbarian|Bard|Cleric|Druid|Fighter|Monk|Paladin|Ranger|Rogue|Sorcerer|Warlock|Wizard)\\s*([0-9]{1,2})")
	var classes=regex.search_all(class_text)
	for item in classes:
		if primary_class.is_empty():primary_class=item.get_string(1).capitalize()
		level+=int(item.get_string(2))
	if classes.size()>1:issues.append("Multiclass sheet: total level imported. Review Hit Dice and class-specific spell resources manually.")
	if primary_class.is_empty():primary_class="Fighter";issues.append("Class/level was not recognized. Choose the correct values below.")
	level=clampi(level,1,20)
	var a=loadouts[primary_class].duplicate(true)
	# Every imported field starts independently; never inherit class-loadout gear or slots.
	a.class_levels={}
	for item in classes:a.class_levels[item.get_string(1).capitalize()]=int(item.get_string(2))
	a.name=name.left(100);a.class=primary_class;a.level=level;a.race=first(fields,["RACE","SPECIES"],"Unknown").left(100)
	a.hero=true;a.owner=1;a.skills={};a.save_profs=[];a.skill_bonuses={};a.save_bonuses={};a.conditions=[];a.slots=[0,0,0,0,0,0,0,0,0];a.slots_max=a.slots.duplicate()
	a.weapon="No basic attack";a.damage="0";a.attack=0;a.notes="";a.inventory="";a.color="#8fa7d1";a.portrait="";a.token_size=1;a.prof_bonus=integer(first(fields,["ProfBonus","ProficiencyBonus"]),R.proficiency(level));a.imported_sheet=true
	var ability_names=["Strength","Dexterity","Constitution","Intelligence","Wisdom","Charisma"]
	for i in 6:
		var value=first(fields,[R.ABILITIES[i],ability_names[i]])
		if value.is_empty():issues.append("Missing "+R.ABILITIES[i]+" score; enter it below.")
		a.abilities[i]=clampi(integer(value,10),1,30)
		var save=first(fields,["ST "+ability_names[i],ability_names[i]+"Save"])
		var prof=first(fields,[R.ABILITIES[i].capitalize()+"Prof",ability_names[i]+"Prof"])
		if not prof.is_empty() and prof!="0":a.save_profs.append(i)
		if not save.is_empty():a.save_bonuses[R.ABILITIES[i]]=integer(save)
	for skill in R.SKILLS:
		var aliases=[skill]
		if skill=="Animal Handling":aliases.append("Animal")
		var value=first(fields,aliases)
		var prof=first(fields,[skill+"Prof"])
		var tier=2 if prof.to_upper() in ["E","EXPERTISE","2"] else 1 if not prof.is_empty() and prof!="0" else 0
		if tier>0:a.skills[skill]=tier
		if not value.is_empty():a.skill_bonuses[skill]=integer(value)
	for entry in [["ac",["AC","ArmorClass"],10,1,40],["max_hp",["MaxHP","HPMax"],1,1,9999],["speed",["Speed","WalkingSpeed"],30,0,300]]:
		var value=first(fields,entry[1])
		if value.is_empty():issues.append("Missing "+str(entry[0]).replace("_"," ")+"; confirm the value below.")
		a[entry[0]]=clampi(integer(value,entry[2]),entry[3],entry[4])
	var current=first(fields,["CurrentHP","HPCurrent"])
	a.hp=clampi(integer(current,a.max_hp),0,a.max_hp);a.temp=clampi(integer(first(fields,["TempHP","HPTemp"])),0,9999)
	a.xp=maxi(0,integer(first(fields,["EXPERIENCE POINTS","XP"])))
	# Lite exposes the printed narrative and reference fields in their own sections.
	for pair in [["personality_traits","PersonalityTraits"],["ideals","Ideals"],["bonds","Bonds"],["flaws","Flaws"],["backstory","Backstory"],["eyes","EYES"],["skin","SKIN"],["hair","HAIR"],["senses","AdditionalSenses"],["proficiencies","ProficienciesLang"]]:a[pair[0]]=first(fields,[pair[1]]).left(30000)
	a.personal_notes=(first(fields,["AdditionalNotes1"])+"\n"+first(fields,["AdditionalNotes2"])).strip_edges().left(30000)
	a.custom_actions=(first(fields,["Actions1"])+"\n"+first(fields,["Actions2"])).strip_edges().left(30000)
	a.multiclass=class_text if classes.size()>1 else ""
	a.inventory_items=[]

	a.token_size=int({"large":2,"huge":3,"gargantuan":4}.get(first(fields,["SIZE"]).to_lower(),1))
	a.size_category=first(fields,["SIZE"],"Medium").capitalize()
	if a.size_category not in ["Tiny","Small","Medium","Large","Huge","Gargantuan"]:a.size_category="Medium"
	for field in [["background","BACKGROUND"],["alignment","ALIGNMENT"],["age","AGE"],["height_text","HEIGHT"],["weight_text","WEIGHT"],["languages","ProficienciesLang"]]:a[field[0]]=first(fields,[field[1]]).left(500)
	if current.is_empty():issues.append("Current HP is blank; it starts at maximum HP unless you change it below.")
	a.initiative_bonus=integer(first(fields,["Init","Initiative"]),R.modifier(a.abilities[1]));a.initiative=0
	var hit=first(fields,["Total","TotalHitDice","HitDice"])
	var die_regex=RegEx.new();die_regex.compile("([0-9]+)d(4|6|8|10|12|20)\\b");var hit_match=die_regex.search(hit)
	a.hit_die=int(hit_match.get_string(2)) if hit_match else int(loadouts[primary_class].hit_die)
	a.hit_dice=clampi(integer(first(fields,["HD","HitDiceRemaining"]),level),0,level)
	if not hit_match:issues.append("Hit Die size was inferred from the first class; confirm it below.")
	var attacks=[]
	for index in range(1,7):
		var suffix="" if index==1 else " "+str(index)
		var weapon=first(fields,["Wpn Name"+suffix,"Wpn"+str(index)+" Name"])
		if weapon.is_empty():continue
		var damage_text=first(fields,["Wpn"+str(index)+" Damage"])
		var damage_regex=RegEx.new();damage_regex.compile("[0-9]+d[0-9]+(?:\\s*[+-]\\s*[0-9]+)?|^[0-9]+")
		var damage_match=damage_regex.search(damage_text)
		var damage=damage_match.get_string().replace(" ","") if damage_match else "0"
		attacks.append({"name":weapon,"bonus":integer(first(fields,["Wpn"+str(index)+" AtkBonus"])),"damage":damage,"source":damage_text,"notes":first(fields,["Wpn Notes "+str(index)])})
	a.attack_profiles=[]
	for attack in attacks:a.attack_profiles.append_array(C.standard(attack.name,attack.bonus,attack.damage,attack.notes))
	if not attacks.is_empty():a.weapon=attacks[0].name;a.attack=attacks[0].bonus;a.damage=attacks[0].damage
	else:issues.append("No basic weapon attack found. You can add one now or in Edit sheet.")
	var inventory=[]
	var weight_regex=RegEx.new();weight_regex.compile("^[0-9]+(?:\\.[0-9]+)?")
	for i in range(0,200):
		var item=first(fields,["Eq Name"+str(i)])
		if item.is_empty():continue
		var quantity=first(fields,["Eq Qty"+str(i)],"1");var weight=first(fields,["Eq Weight"+str(i)])
		inventory.append(item+" × "+quantity+(" ("+weight+")" if not weight.is_empty() else ""))
		var weight_match=weight_regex.search(weight.strip_edges())
		a.inventory_items.append({"name":item.left(100),"quantity":clampi(integer(quantity,1),0,9999),"weight":clampf(float(weight_match.get_string()),0,10000) if weight_match else 0.0,"equipped":false,"attuned":false,"notes":"Imported equipment; confirm equipped/attuned state and weight with the DM."})
	a.coins={}
	var money=[]
	for coin in ["CP","SP","EP","GP","PP"]:
		var amount=first(fields,[coin]);a.coins[coin.to_lower()]=clampi(integer(amount),0,9999999)
		if not amount.is_empty():money.append(amount+" "+coin.to_lower())
	if not money.is_empty():inventory.append("Coins: "+", ".join(money))
	a.inventory="\n".join(inventory)
	var notes=["Imported character sheet: "+filename,"Classes on sheet: "+class_text,"2014 tabletop rules. Imported feature text is reference; the DM resolves features and spells."]
	var background=first(fields,["BACKGROUND"])
	if not background.is_empty():notes.append("Background: "+background)
	for key in ["ALIGNMENT","EXPERIENCE POINTS","ProficienciesLang","Defenses","SaveModifiers","AdditionalSenses","FeaturesTraits1","FeaturesTraits2","FeaturesTraits3","Actions1","Actions2","PersonalityTraits","Ideals","Bonds","Flaws","Backstory","AdditionalNotes1","AdditionalNotes2"]:
		var value=first(fields,[key])
		if not value.is_empty():notes.append(key+":\n"+value)
	if not attacks.is_empty():
		var lines=[]
		for attack in attacks:lines.append(attack.name+" · "+R.signed_n(attack.bonus)+" · "+attack.source+" · "+attack.notes)
		notes.append("Attacks from sheet:\n"+"\n".join(lines))
	# Each spell header identifies its actual level; header indices are not levels.
	var slot_regex=RegEx.new();slot_regex.compile("(?i)([0-9]+)\\s*slots?")
	for i in 30:
		var header=first(fields,["spellHeader"+str(i)]);var slot=first(fields,["spellSlotHeader"+str(i)])
		var slot_match=slot_regex.search(slot);var spell_level=integer(header)
		if slot_match and spell_level>=1 and spell_level<=9:a.slots_max[spell_level-1]=clampi(int(slot_match.get_string(1)),0,9)
	a.slots=a.slots_max.duplicate()
	a.spellcasting=[]
	for i in 12:
		var casting_class=first(fields,["spellCastingClass"+str(i)]);var ability=first(fields,["spellCastingAbility"+str(i)])
		if casting_class.is_empty() and ability.is_empty():continue
		a.spellcasting.append({"class":casting_class,"ability":ability,"dc":integer(first(fields,["spellSaveDC"+str(i)])),"attack":integer(first(fields,["spellAtkBonus"+str(i)]))})
	if not a.spellcasting.is_empty():
		var casting_notes=[]
		for casting in a.spellcasting:casting_notes.append(casting.class+" · "+casting.ability+" · Save DC "+str(casting.dc)+" · Spell attack "+R.signed_n(casting.attack))
		notes.append("Spellcasting values from sheet:\n"+"\n".join(casting_notes))
	a.spellbook=[]
	for i in 200:
		var spell=first(fields,["spellName"+str(i)])
		if spell.is_empty():continue
		var prepared=first(fields,["spellPrepared"+str(i)]);var details=[]
		for suffix in ["Source","SaveHit","CastingTime","Range","Components","Duration","Notes"]:
			var value=first(fields,["spell"+suffix+str(i)])
			if not value.is_empty():details.append(suffix+": "+value)
		a.spellbook.append({"name":spell,"prepared":prepared,"details":" · ".join(details)})
	if not a.spellbook.is_empty():
		var spell_notes=[]
		for spell in a.spellbook:spell_notes.append(spell.name+(" ["+spell.prepared+"]" if not spell.prepared.is_empty() else "")+" · "+spell.details)
		notes.append("Spells from sheet (prepared marks preserved as printed):\n"+"\n".join(spell_notes))
	if a.slots_max.any(func(n):return n>0):issues.append("Spell-slot maximums imported; remaining slots start full. Review spent slots in Edit sheet.")
	a.notes="\n\n".join(notes).left(100000)
	if a.hp==0:a.conditions.append("Unconscious")
	return {"ok":true,"actor":a,"issues":issues,"attacks":attacks,"fields":fields.size(),"filename":filename,"classes":classes.size()}
