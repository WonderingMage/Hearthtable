extends RefCounted
# 2014 SRD spell/resource runtime. Commands are validated on the host before spending resources.
const R=preload("res://scripts/rules.gd")
const C=preload("res://scripts/combat_rules.gd")
const COMMANDS=["cast_spell","learn_spell","prepare_spell","forget_spell","custom_spell","feature_use","feature_set","sheet_notes","inspiration","concentration_save","end_concentration","spell_save","finish_short_rest","spell_settings","spell_useset","inventory_item","coins"]
const ATTACKS=["acidarrow","chilltouch","eldritchblast","firebolt","guidingbolt","inflictwounds","rayoffrost","scorchingray","shockinggrasp","vampirictouch"]
const SAVES=["acidsplash","burninghands","calllightning","chainlightning","circleofdeath","coneofcold","conjurebarrage","destructivewave","disintegrate","fireball","flamestrike","harm","lightningbolt","poisonspray","rayofsickness","sacredflame","shatter","thunderwave","viciousmockery"]
const SAFE_SAVES=["acidsplash","burninghands","circleofdeath","coneofcold","fireball","flamestrike","lightningbolt","poisonspray","sacredflame","shatter","thunderwave","viciousmockery"]
const HEALS=["curewounds","healingword","masscurewounds","masshealingword","heal"]
const DEFAULTS={"Wizard":["Fire Bolt","Ray of Frost","Mage Hand","Magic Missile","Shield","Burning Hands","Mage Armor","Detect Magic","Sleep"],"Cleric":["Sacred Flame","Guidance","Light","Cure Wounds","Healing Word","Bless","Shield of Faith","Detect Magic"],"Druid":["Produce Flame","Guidance","Druidcraft","Cure Wounds","Healing Word","Entangle","Faerie Fire","Detect Magic"],"Bard":["Vicious Mockery","Mage Hand","Healing Word","Cure Wounds","Thunderwave","Detect Magic"],"Sorcerer":["Fire Bolt","Ray of Frost","Light","Mage Hand","Magic Missile","Shield"],"Warlock":["Eldritch Blast","Chill Touch","Hellish Rebuke","Charm Person"],"Paladin":["Cure Wounds","Bless","Shield of Faith"],"Ranger":["Cure Wounds","Detect Magic","Longstrider"]}
var w: Node
func _init(world: Node):w=world
func key(name: String) -> String:return C.key(name)
func base_class(a: Dictionary) -> String:
	for cls in DEFAULTS:
		if str(a.class).to_lower().contains(str(cls).to_lower()):return cls
	return str(a.class).split(" ")[0]
func ability(a: Dictionary) -> int:
	return clampi(int(a.get("spell_ability",3 if base_class(a)=="Wizard" else 4 if base_class(a) in ["Cleric","Druid","Ranger"] else 5)),0,5)
func dc(a: Dictionary) -> int:return int(a.get("spell_dc",8+R.proficiency(a.level)+R.modifier(a.abilities[ability(a)])))
func attack_bonus(a: Dictionary) -> int:return int(a.get("spell_attack",R.proficiency(a.level)+R.modifier(a.abilities[ability(a)])))
func definition(a: Dictionary,k: String) -> Dictionary:
	for s in a.get("custom_spells",[]):
		if key(s.name)==k:return s
	return w.spell_lookup.get(k,{})
func entry(a: Dictionary,k: String) -> Dictionary:
	for s in a.get("known_spells",[]):
		if s.key==k:return s
	return {}
func ensure(a: Dictionary):
	if not a.has("known_spells"):
		a.known_spells=[];a.custom_spells=[]
		var imported=a.get("spellbook",[])
		if not imported.is_empty():
			for s in imported:
				var k=key(str(s.name));var def=w.spell_lookup.get(k,{})
				if def.is_empty():a.custom_spells.append({"name":str(s.name),"level":1,"range":"30 feet","casting_time":"1 action","duration":"See sheet","concentration":false,"ritual":false,"desc":[str(s.get("details",""))],"custom":true,"needs_review":true})
				var mark=str(s.get("prepared","")).strip_edges().to_lower()
				var prepared=int(def.get("level",1))==0 or base_class(a) not in ["Cleric","Druid","Wizard","Paladin"] or mark not in ["","no","false","0","off","unprepared","o","○","◯","◦"]
				if entry(a,k).is_empty():a.known_spells.append({"key":k,"name":str(s.name),"prepared":prepared})
		elif a.hero:
			var prepared=0
			for name in DEFAULTS.get(base_class(a),[]):
				var s=w.spell_lookup.get(key(name),{})
				if s.is_empty() or (base_class(a) in ["Paladin","Ranger"] and int(a.level)<2):continue
				var available=int(s.level)==0 or prepared<preparation_limit(a)
				a.known_spells.append({"key":key(name),"name":name,"prepared":available})
				if int(s.level)>0 and available:prepared+=1
		else:
			var monster=w.monster_lookup.get(str(a.get("monster_index",a.name)).to_lower(),{})
			for feature in monster.get("special_abilities",[]):
				if not feature.has("spellcasting"):continue
				var casting=feature.spellcasting
				for s in casting.get("spells",[]):a.known_spells.append({"key":key(s.name),"name":s.name,"prepared":true})
				for l in casting.get("slots",{}):a.slots_max[int(l)-1]=int(casting.slots[l]);a.slots[int(l)-1]=int(casting.slots[l])
				a.spell_ability=maxi(0,R.ABILITIES.find(str(casting.ability.name)));a.spell_dc=int(casting.dc);a.spell_attack=int(casting.modifier)
		if not a.get("spellcasting",[]).is_empty():
			var cast=a.spellcasting[0];var idx=R.ABILITIES.find(str(cast.ability).to_upper().left(3))
			if idx>=0:a.spell_ability=idx
			if int(cast.dc)>0:a.spell_dc=int(cast.dc)
			a.spell_attack=int(cast.attack)
	if not a.has("custom_spells"):a.custom_spells=[]
	if not a.has("features"):
		a.features=[]
		var cls=base_class(a);var level=int(a.level)
		match cls:
			"Barbarian":add_feature(a,"Rage",2 if level<3 else 3 if level<6 else 4 if level<12 else 5 if level<17 else 6,"long")
			"Bard":add_feature(a,"Bardic Inspiration",maxi(1,R.modifier(a.abilities[5])),"short" if level>=5 else "long")
			"Cleric","Paladin":
				if level>=2:add_feature(a,"Channel Divinity",3 if cls=="Cleric" and level>=18 else 2 if cls=="Cleric" and level>=6 else 1,"short")
				if cls=="Paladin":add_feature(a,"Lay on Hands",5*level,"long");add_feature(a,"Divine Sense",maxi(1,1+R.modifier(a.abilities[5])),"long")
			"Druid":
				if level>=2:add_feature(a,"Wild Shape",2,"short")
			"Fighter":
				add_feature(a,"Second Wind",1,"short")
				if level>=2:add_feature(a,"Action Surge",2 if level>=17 else 1,"short")
			"Monk":
				if level>=2:add_feature(a,"Ki",level,"short")
			"Sorcerer":
				if level>=2:add_feature(a,"Sorcery Points",level,"long")
			"Wizard":add_feature(a,"Arcane Recovery",1,"long")
	for name in ["pending_saves","concentration_checks"]:
		if not a.has(name):a[name]=[]
	if not a.has("concentration"):a.concentration={}
	if not a.has("inspiration"):a.inspiration=false
	if not a.has("inventory_items"):a.inventory_items=[]
	if not a.has("coins"):a.coins={"cp":0,"sp":0,"ep":0,"gp":0,"pp":0}
func preparation_limit(a: Dictionary) -> int:
	if int(a.get("prepared_limit",-1))>=0:return int(a.prepared_limit)
	if not a.hero:return 999
	var cls=base_class(a)
	if cls in ["Cleric","Druid","Wizard"]:return maxi(1,int(a.level)+R.modifier(a.abilities[ability(a)]))
	if cls=="Paladin":return 0 if int(a.level)<2 else maxi(1,int(a.level/2.0)+R.modifier(a.abilities[ability(a)]))
	return 999
func prepared_count(a: Dictionary) -> int:
	var total=0
	for e in a.get("known_spells",[]):
		if e.get("prepared",false) and int(definition(a,e.key).get("level",0))>0:total+=1
	return total
func add_feature(a: Dictionary,name: String,maximum: int,recharge: String):a.features.append({"name":name,"max":maximum,"remaining":maximum,"recharge":recharge})
func mode(s: Dictionary) -> String:
	var k=key(s.name)
	if k in ["magicmissile","eldritchblast","scorchingray"]:return "volley"
	if k in ATTACKS and k not in ["acidarrow","vampirictouch"]:return "attack"
	if k in SAFE_SAVES:return "save"
	if k in HEALS:return "heal"
	return "manual"
func automation(s: Dictionary) -> String:
	if key(s.name) in ["shield","shieldoffaith","bless","guidance","resistance","magearmor","invisibility"]:return "Applies the named effect automatically. Concentration and supported turn expiry remove it. DM handles elapsed time outside combat and special exceptions."
	match mode(s):
		"attack":return "Spell attack + damage; secondary effects need the DM."
		"volley":return "Each dart/beam resolves separately. Allocate all darts/beams to targets."
		"save":return "Saving throw + damage. Players roll their own pending saves; DM handles riders and damage traits."
		"heal":return "Healing applied, with spellcasting modifier where printed. Conditions and other riders need the DM."
	return "Slot, timing, range and concentration tracked. DM resolves this spell’s effects from its rules text."
func count(s: Dictionary,a: Dictionary,slot: int) -> int:
	match key(s.name):
		"magicmissile":return 2+slot
		"scorchingray":return 1+slot
		"eldritchblast":return 1+int(a.level>=5)+int(a.level>=11)+int(a.level>=17)
	return 1
func formula(s: Dictionary,a: Dictionary,slot: int,healing: bool=false) -> String:
	var damage=s.get("damage",[])
	var first=damage[0] if damage is Array and not damage.is_empty() else {}
	var table=s.get("heal_at_slot_level",{}) if healing else first.get("damage_at_slot_level",{})
	if table.is_empty() and not healing:table=first.get("damage_at_character_level",{})
	var threshold=slot if healing or first.has("damage_at_slot_level") else int(a.level)
	var best=-1;var expression=""
	for l in table:
		if int(l)<=threshold and int(l)>best:best=int(l);expression=str(table[l])
	return expression.replace("MOD",str(R.modifier(a.abilities[ability(a)]))).replace("+ -","-")
func range_feet(s: Dictionary) -> float:
	var text=str(s.get("range","Self"))
	if text=="Touch":return 5.0
	if text=="Self":return 0.0
	if text in ["Sight","Unlimited","Special"]:return 528000.0
	var found=C.match_one("([0-9]+)",text)
	if found:return float(found.get_string(1))*(5280.0 if text.contains("mile") else 1.0)
	return 0.0
func assessment(a: Dictionary,p: Dictionary,peer: int=1) -> Dictionary:
	var result={"ok":false,"reason":"Choose a spell on this character’s sheet."}
	if a.is_empty():return result
	ensure(a)
	var k=str(p.get("spell",""));var known=entry(a,k);var s=definition(a,k)
	if known.is_empty() or s.is_empty():return result
	if s.get("needs_review",false):result.reason="DM must review this imported spell’s level, range and casting time first.";return result
	if not known.get("prepared",false) and int(s.level)>0 and not (p.get("ritual",false) and base_class(a)=="Wizard"):result.reason="Prepare this spell on the character sheet first.";return result
	if w.encounter.is_raging(a):result.reason="A raging character cannot cast spells.";return result
	if C.incapacitated(a):result.reason="An incapacitated character or one at 0 HP cannot cast.";return result
	if a.scene!=w.data.scene:result.reason="The caster must be in the active scene.";return result
	var level=int(s.level);var slot=int(p.get("slot",level));var ritual=bool(p.get("ritual",false));var free_use=bool(p.get("free_use",false))
	if slot<level or slot>9 or slot<0:result.reason="Choose a slot of the spell’s level or higher.";return result
	if (ritual or free_use) and slot!=level:result.reason="Ritual and configured innate casting use the spell’s base level.";return result
	if free_use:
		if ritual or int(known.get("uses",0))<=0:result.reason="No innate/feature uses remain.";return result
	elif ritual:
		if not s.get("ritual",false) or base_class(a) not in ["Wizard","Cleric","Druid","Bard"]:result.reason="This character/spell has no configured ritual casting. DM can add a custom feature.";return result
		if w.encounter.strict():result.reason="Rituals take 10 extra minutes. Finish the encounter first.";return result
	elif level>0 and int(a.slots[slot-1])<=0:result.reason="No level "+str(slot)+" spell slots remain.";return result
	var time=str(s.get("casting_time","1 action"));var cost="bonus" if time.contains("bonus") else "reaction" if time.contains("reaction") else "action"
	var turn=str(w.data.combat.get("serial",0))
	if w.encounter.strict():
		var combat=w.data.combat
		if not time in ["1 action","1 bonus action","1 reaction"] and not time.begins_with("1 reaction"):
			result.reason="Long casting times need DM resolution outside the automated combat turn.";return result
		if cost!="reaction" and (combat.order.is_empty() or combat.order[clampi(int(combat.turn),0,combat.order.size()-1)]!=a.id):result.reason="Wait for this character’s turn to cast an action or bonus-action spell.";return result
		if (cost=="action" and not w.encounter.has_action(a)) or (cost!="action" and a.get(cost,false)):result.reason="This character has already used their "+cost+". DM can reset its marker for a feature or correction.";return result
		var castings=a.get("turn_castings",{})
		if str(castings.get("turn",""))==turn:
			if castings.get("bonus",false) and not (level==0 and cost=="action"):result.reason="2014 bonus-action rule: another spell this turn must be a cantrip with a casting time of 1 action.";return result
			if cost=="bonus" and castings.get("other",false):result.reason="2014 bonus-action rule: a non-cantrip/action spell was already cast this turn.";return result
	var ids=p.get("targets",[])
	if p.get("auto_area",false) and s.has("area_of_effect"):
		ids=w.encounter.area_targets(a,s,Vector2i(int(p.get("origin_x",a.x)),int(p.get("origin_y",a.y)))).map(func(t):return t.id)
	if not ids is Array or ids.size()>64:result.reason="Invalid target list.";return result
	var targets=[];var automated=mode(s)
	var origin=a
	if s.has("area_of_effect") and str(s.range)!="Self":
		if not p.has("origin_x") or not p.has("origin_y"):result.reason="Choose the area’s origin square (use the map template as a guide).";return result
		var x=int(p.origin_x);var y=int(p.origin_y)
		if x<0 or y<0 or x>=int(w.scene().width) or y>=int(w.scene().height):result.reason="The spell’s origin must be inside the scene.";return result
		origin={"x":x,"y":y,"token_size":1,"elevation_ft":w.encounter.elevation(Vector2i(x,y))}
		if C.clear_distance(a,origin,w.scene()).distance>range_feet(s)+0.0001:result.reason="The area’s origin is beyond range or blocked by a wall/closed door.";return result

	for id in ids:
		var target=w.actor(str(id))
		if target.is_empty() or target.scene!=a.scene or (peer!=1 and not w.visible(target) and not p.get("auto_area",false)):result.reason="Choose visible targets in this scene.";return result
		var limit=range_feet(s)
		if s.has("area_of_effect"):
			if C.distance(origin,target,w.scene())>float(s.area_of_effect.size)+0.0001:result.reason=target.name+" is beyond the spell area’s maximum extent from its origin.";return result
		elif a.id!=target.id:
			var line=C.clear_distance(a,target,w.scene())
			if C.distance(a,target,w.scene())>limit+0.0001:result.reason=target.name+" is outside this spell’s "+str(s.range)+" range.";return result
			if line.distance>limit+0.0001:result.reason="A wall or closed door blocks the spell’s direct path to "+target.name+".";return result
		if automated=="heal" and (target.get("dead",false) or (str(target.race).to_lower().contains("undead") or str(target.race).to_lower().contains("construct"))):result.reason="This healing cannot affect a dead creature, undead or construct.";return result
		targets.append(target)
	if key(s.name)=="acidsplash" and targets.size()==2 and C.distance(targets[0],targets[1],w.scene())>5.0001:result.reason="Acid Splash targets must be within 5 feet of each other.";return result
	if k in ["bless","shieldoffaith","guidance","resistance","magearmor","invisibility"]:
		var maximum=slot+2 if k=="bless" else maxi(1,slot-1) if k=="invisibility" else 1
		if targets.is_empty() or targets.size()>maximum:result.reason="Choose 1–"+str(maximum)+" target(s) for this spell.";return result
		var unique={}
		for target in targets:
			if unique.has(target.id):result.reason="Choose each target only once.";return result
			unique[target.id]=true
		if k=="magearmor" and targets.any(func(t):return t.get("armor_equipped",false)):result.reason="Mage Armor requires an unarmored target. Review armor in Combat settings.";return result
	var required=count(s,a,slot)
	if automated in ["attack","volley"] and targets.size()!=required:result.reason="Allocate exactly "+str(required)+" attack(s)/dart(s).";return result
	if automated in ["heal","save"] and targets.is_empty():result.reason="Select at least one target.";return result
	if automated in ["heal","save"]:
		var maximum=6 if key(s.name).begins_with("mass") else 3 if key(s.name)=="chainlightning" else 2 if key(s.name)=="acidsplash" else 64 if s.has("area_of_effect") else 1
		if targets.size()>maximum:result.reason="Too many targets for this spell.";return result
		var distinct={}
		for target in targets:
			if distinct.has(target.id):result.reason="Choose each target only once.";return result
			distinct[target.id]=true
	if (s.has("area_of_effect") or key(s.name) in ["acidsplash","chainlightning"]) and not p.get("area_confirmed",false):result.reason="Confirm the template, target arrangement and cover with the DM.";return result
	if not p.get("components",false):result.reason="Confirm components and any reaction trigger with the DM before casting.";return result
	result.merge({"ok":true,"reason":"Ready to cast.","spell":s,"slot":slot,"ritual":ritual,"cost":cost,"targets":targets,"turn":turn,"free_use":free_use},true)
	return result
func handle(kind: String,p: Dictionary,peer: int) -> bool:
	if kind not in COMMANDS:return false
	var a=w.actor(str(p.get("id","")))
	if not w.can_control(a,peer):w.reject_command(peer,"You control only your assigned characters.");return true
	ensure(a)
	var assessment_result={}
	if kind=="cast_spell":
		assessment_result=assessment(a,p,peer)
		if not assessment_result.ok:w.reject_command(peer,assessment_result.reason);return true
		if w.director.spell(a,assessment_result,peer):return true
	if kind=="prepare_spell":
		var e=entry(a,str(p.get("spell","")))
		if w.data.combat.active:w.reject_command(peer,"Prepare spells outside combat after the required rest/study, with DM approval.");w.changed.emit();return true
		if not e.is_empty() and not e.get("prepared",false) and prepared_count(a)>=preparation_limit(a):w.reject_command(peer,"Preparation limit reached. Unprepare another spell, or ask the DM to adjust the limit.");w.changed.emit();return true
	if kind=="feature_use":
		var index=int(p.get("index",-1))
		if index>=0 and index<a.features.size():
			var gate=w.encounter.feature_gate(a,a.features[index],int(p.get("amount",1)),p)
			if not gate.is_empty():w.reject_command(peer,gate);return true
	if kind in ["feature_set","custom_spell","spell_settings","spell_useset"] and peer!=1:w.reject_command(peer,"Ask the DM to configure spell/feature rules.");return true
	w.history.append(w.data.duplicate(true))
	if w.history.size()>20:w.history.pop_front()
	match kind:
		"cast_spell":cast(a,assessment_result,p)
		"spell_useset":
			var e=entry(a,str(p.get("spell","")))
			if not e.is_empty():e.uses_max=clampi(int(p.get("max",0)),0,100);e.uses=clampi(int(p.get("uses",e.uses_max)),0,int(e.uses_max));e.recharge=str(p.get("recharge","long")) if p.get("recharge","long") in ["short","long","none"] else "long"
		"inventory_item":
			var index=int(p.get("index",-1));var item=p.get("item",{})
			if p.get("delete",false):
				if index>=0 and index<a.inventory_items.size():a.inventory_items.remove_at(index)
			elif item is Dictionary:
				var attuned=bool(item.get("attuned",false));var attuned_count=0
				for i in a.inventory_items.size():
					if i!=index and a.inventory_items[i].attuned:attuned_count+=1
				if attuned and attuned_count>=3:w.reject_command(peer,"2014 default: at most 3 attuned items. Record a class exception with the DM in notes.");return true
				var value={"name":str(item.get("name","Item")).left(100),"quantity":clampi(int(item.get("quantity",1)),0,9999),"weight":clampf(float(item.get("weight",0)),0,10000),"equipped":bool(item.get("equipped",false)),"attuned":attuned,"notes":str(item.get("notes","")).left(4000)}
				if index>=0 and index<a.inventory_items.size():a.inventory_items[index]=value
				elif a.inventory_items.size()<300:a.inventory_items.append(value)
		"coins":
			for coin in ["cp","sp","ep","gp","pp"]:a.coins[coin]=clampi(int(p.get(coin,a.coins[coin])),0,9999999)

		"learn_spell":
			var k=str(p.get("spell",""));var s=w.spell_lookup.get(k,{})
			if not s.is_empty() and entry(a,k).is_empty() and a.known_spells.size()<500:a.known_spells.append({"key":k,"name":s.name,"prepared":int(s.level)==0});w.log_line(a.name+" added "+s.name+" to their spellbook. DM confirms class/level eligibility.",[a.id])
		"prepare_spell":
			var e=entry(a,str(p.get("spell","")))
			if not e.is_empty():e.prepared=not e.get("prepared",false)
		"forget_spell":
			var e=entry(a,str(p.get("spell","")))
			if not e.is_empty():a.known_spells.erase(e)
		"custom_spell":
			var s=p.get("spell",{})
			if s is Dictionary and not str(s.get("name","")).strip_edges().is_empty():
				var def={"name":str(s.name).left(100),"level":clampi(int(s.get("level",1)),0,9),"range":str(s.get("range","30 feet")).left(40),"casting_time":str(s.get("casting_time","1 action")).left(50),"duration":str(s.get("duration","See sheet")).left(60),"concentration":bool(s.get("concentration",false)),"ritual":bool(s.get("ritual",false)),"desc":[str(s.get("text","")).left(20000)],"custom":true}
				var k=key(def.name)
				a.custom_spells=a.custom_spells.filter(func(old):return key(old.name)!=k);a.custom_spells.append(def)
				if entry(a,k).is_empty():a.known_spells.append({"key":k,"name":def.name,"prepared":true})
		"feature_use":
			var i=int(p.get("index",-1));var amount=clampi(int(p.get("amount",1)),1,1000)
			if i>=0 and i<a.features.size():
				var f=a.features[i]
				if int(f.remaining)<amount:w.reject_command(peer,"Not enough uses remain.");return true
				f.remaining-=amount;var automated=w.encounter.use_feature(a,f,amount,p);w.log_line(a.name+" used "+f.name+" ×"+str(amount)+" · "+str(f.remaining)+"/"+str(f.max)+" remain."+(" Effects applied." if automated else " Resolve the feature’s effects with the DM."),[a.id])
		"feature_set":
			var i=int(p.get("index",-1));var maximum=clampi(int(p.get("max",1)),0,1000)
			var f={"name":str(p.get("name","Custom feature")).left(100),"max":maximum,"remaining":clampi(int(p.get("remaining",maximum)),0,maximum),"recharge":str(p.get("recharge","long")) if p.get("recharge","long") in ["short","long","none"] else "long"}
			if i>=0 and i<a.features.size():
				if p.get("delete",false):a.features.remove_at(i)
				else:a.features[i]=f
			elif a.features.size()<100:a.features.append(f)
		"sheet_notes":a.notes=str(p.get("notes",a.notes)).left(100000);a.inventory=str(p.get("inventory",a.inventory)).left(50000)
		"inspiration":a.inspiration=not a.inspiration;w.log_line(a.name+(" gained" if a.inspiration else " spent")+" inspiration (apply advantage using the roll selector).",[a.id])
		"spell_settings":
			a.spell_ability=clampi(int(p.get("ability",ability(a))),0,5);a.prepared_limit=clampi(int(p.get("prepared_limit",-1)),-1,999)
			if p.get("automatic",true):a.erase("spell_dc");a.erase("spell_attack")
			else:a.spell_dc=clampi(int(p.get("dc",dc(a))),0,50);a.spell_attack=clampi(int(p.get("attack",attack_bonus(a))),-20,50)
		"end_concentration":end_concentration(a)
		"concentration_save":concentration_roll(a,int(p.get("mode",0)))
		"spell_save":
			if not a.pending_saves.is_empty():resolve_save(a,a.pending_saves.pop_front(),int(p.get("mode",0)))
		"finish_short_rest":
			if w.data.combat.active:w.reject_command(peer,"Finish the encounter before resting.");return true
			recover(a,"short");w.log_line(a.name+" completed a 1-hour short rest. Eligible counters"+(" and Pact Magic slots" if base_class(a)=="Warlock" else "")+" restored.",[a.id])
	w.mark_changed();return true
func cast(a: Dictionary,result: Dictionary,p: Dictionary):
	var s=result.spell;var k=key(s.name);var level=int(s.level)
	if result.free_use:entry(a,k).uses-=1
	elif level>0 and not result.ritual:a.slots[int(result.slot)-1]-=1
	if w.data.combat.active:
		if result.cost=="action":w.encounter.spend_action(a);a.attacks_left=0
		else:a[result.cost]=true
		var castings=a.get("turn_castings",{})
		if str(castings.get("turn",""))!=result.turn:castings={"turn":result.turn,"bonus":false,"other":false}
		if result.cost=="bonus":castings.bonus=true
		elif not (level==0 and result.cost=="action"):castings.other=true
		a.turn_castings=castings
	w.encounter.break_invisibility(a)
	if s.get("concentration",false):
		end_concentration(a);a.concentration={"spell":s.name,"targets":p.get("targets",[]),"duration":str(s.duration)}
		if not a.conditions.has("Concentrating"):a.conditions.append("Concentrating")
	w.log_line("✦ "+a.name+" cast "+s.name+(" · innate/feature use spent" if result.free_use else " as a ritual (+10 minutes)" if result.ritual else " · cantrip" if level==0 else " · level "+str(result.slot)+" slot spent")+(" · concentration" if s.get("concentration",false) else ""),[a.id])
	var automated=mode(s);var targets=result.targets
	if w.encounter.spell_effect(a,s,targets,int(result.slot)):return
	if automated=="manual":w.log_line("DM resolution: "+s.name+" · "+str(s.duration)+". "+automation(s),[a.id]);return
	var expression=formula(s,a,int(result.slot),automated=="heal")
	if k=="magicmissile":
		var dart_roll=R.roll("1d4+1");w.director.record(a,"Magic Missile · damage",dart_roll,4);var dart=dart_roll.total
		for target in targets:
			if target.get("effects",[]).any(func(e):return e.get("kind","")=="shield"):w.encounter.outcome("attack",a,target,"Magic Missile","BLOCKED by Shield",{"hit":false});continue
			w.encounter.outcome("attack",a,target,"Magic Missile","AUTO HIT · dart "+str(dart)+" force",{"hit":true});w.apply_damage(target,int(dart),false,"force")
		w.log_line("Magic Missile: each dart dealt "+str(dart)+" force damage. Shield and configured force-damage traits are applied automatically.",[a.id]);return
	if automated in ["attack","volley"]:
		for target in targets:spell_attack(a,target,s,expression,int(p.get("mode",0)))
	elif automated=="heal":
		var roll=R.roll(expression);w.director.record(a,str(s.name)+" · healing",roll,int(roll.get("sides",0)))
		for target in targets:
			if roll.ok:w.heal(target,maxi(0,int(roll.total)))
	elif automated=="save":
		var damage=R.roll(expression);w.director.record(a,str(s.name)+" · damage",damage,int(damage.get("sides",0)))
		if not damage.ok:w.log_line("DM: resolve damage expression "+expression,[a.id]);return
		var save_index=R.ABILITIES.find(str(s.get("dc",{}).get("dc_type",{}).get("name","DEX")))
		for target in targets:
			ensure(target)
			var task={"spell":s.name,"dc":dc(a),"ability":maxi(0,save_index),"damage":maxi(0,int(damage.total)),"half":s.get("dc",{}).get("dc_success","none")=="half","damage_type":str(s.get("damage",[{}])[0].get("damage_type",{}).get("index",""))}
			if target.hero and not w.data.get("automation",{}).get("auto_saves",true):target.pending_saves.append(task);w.log_line(target.name+" must roll "+R.ABILITIES[task.ability]+" vs DC "+str(task.dc)+" for "+s.name+" (sheet → pending saves).",[a.id,target.id])
			else:resolve_save(target,task,0)
func spell_attack(a: Dictionary,target: Dictionary,s: Dictionary,expression: String,chosen_mode: int):
	var adv=[];var dis=[]
	if chosen_mode==1:adv.append("chosen")
	if chosen_mode==2:dis.append("chosen")
	for condition in ["Blinded","Poisoned","Prone","Restrained"]:
		if a.conditions.has(condition):dis.append(condition)
	if a.conditions.has("Invisible"):adv.append("invisible")
	if target.conditions.has("Invisible"):dis.append("invisible")
	if target.get("dodging",false) and not C.incapacitated(target) and not target.conditions.has("Blinded") and not a.conditions.has("Invisible"):dis.append("dodge")
	for condition in ["Blinded","Restrained","Stunned","Paralyzed","Petrified","Unconscious"]:
		if target.conditions.has(condition):adv.append(condition)
	var distance=C.distance(a,target,w.scene())
	if target.conditions.has("Prone"):
		if distance<=5:adv.append("prone")
		else:dis.append("prone")
	if s.get("attack_type","ranged")=="ranged" and not a.get("ignore_close_range",false):
		for enemy in w.data.actors:
			if enemy.id!=a.id and enemy.scene==a.scene and C.hostile(a,enemy) and not C.incapacitated(enemy) and not enemy.conditions.has("Blinded") and C.clear_distance(a,enemy,w.scene()).distance<=5:dis.append("close hostile");break
	var roll=R.d20(attack_bonus(a),C.roll_mode(adv,dis));var bonus=w.encounter.bonus_die(a,"attack");roll.total+=int(bonus.amount)
	var armor=w.encounter.effective_ac(target)+w.encounter.cover_bonus(target)
	roll.bonus=attack_bonus(a)+int(bonus.amount);w.director.record(a,str(s.name)+" · attack",roll,20,target,"vs AC "+str(armor))
	var hit=roll.natural==20 or (roll.natural!=1 and roll.total>=armor)
	var critical=hit and (roll.natural==20 or (distance<=5 and (target.conditions.has("Paralyzed") or target.conditions.has("Unconscious"))))
	w.log_line(s.name+" → "+target.name+" · "+str(roll.total)+" vs AC "+str(armor)+(" · CRITICAL" if critical else " · HIT" if hit else " · MISS"),[a.id,target.id])
	w.encounter.outcome("attack",a,target,s.name,("CRITICAL" if critical else "HIT" if hit else "MISS")+" · d20 "+str(roll.dice)+" "+R.signed_n(attack_bonus(a))+" vs AC "+str(armor)+(" · "+bonus.text if not bonus.text.is_empty() else ""),{"hit":hit,"critical":critical,"total":roll.total,"ac":armor})
	if hit:
		var damage=R.roll(expression,critical);w.director.record(a,str(s.name)+" · damage",damage,int(damage.get("sides",0)),target)
		if damage.ok:w.apply_damage(target,maxi(0,int(damage.total)),critical,str(s.get("damage",[{}])[0].get("damage_type",{}).get("index","")))
func save_roll(a: Dictionary,index: int,chosen_mode: int) -> Dictionary:
	if index in [0,1] and a.conditions.any(func(c):return c in ["Paralyzed","Petrified","Stunned","Unconscious"]):return {"total":-999,"natural":0,"dice":[]}
	var bonus=R.modifier(int(a.abilities[index]))+(R.proficiency(a.level) if a.save_profs.has(index) else 0)
	bonus=int(a.get("save_bonuses",{}).get(R.ABILITIES[index],bonus))
	var dis=["chosen"] if chosen_mode==2 else []
	if index==1 and a.conditions.has("Restrained"):dis.append("restrained")
	var adv=["chosen"] if chosen_mode==1 else []
	if index==1 and a.get("dodging",false) and not C.incapacitated(a):adv.append("dodge")
	var roll=R.d20(bonus,C.roll_mode(adv,dis));var extra=w.encounter.bonus_die(a,"save",true);roll.total+=int(extra.amount)
	roll.bonus=bonus+int(extra.amount);w.director.record(a,R.ABILITIES[index]+" saving throw",roll)
	return roll
func resolve_save(a: Dictionary,task: Dictionary,chosen_mode: int):
	var roll=save_roll(a,int(task.ability),chosen_mode);var success=roll.total>=int(task.dc)
	var damage=int(task.damage/2.0) if success and task.half else 0 if success else int(task.damage)
	w.log_line(a.name+" · "+task.spell+" "+R.ABILITIES[int(task.ability)]+" save "+str(roll.total)+" vs DC "+str(task.dc)+(" · success" if success else " · failure"),[a.id])
	w.encounter.outcome("save",a,a,task.spell,("SAVED" if success else "FAILED")+" · "+R.ABILITIES[int(task.ability)]+" "+str(roll.total)+" vs DC "+str(task.dc),{"total":roll.total,"dc":task.dc,"success":success})
	w.apply_damage(a,damage,false,str(task.get("damage_type","")))
func end_concentration(a: Dictionary):
	ensure(a)
	if not a.concentration.is_empty():w.log_line(a.name+" ended concentration on "+str(a.concentration.spell)+". Remove its ongoing effects with the DM.",[a.id])
	w.encounter.end_effects(a.id)
	a.concentration={};a.concentration_checks=[];a.conditions.erase("Concentrating")
func damaged(a: Dictionary,amount: int):
	ensure(a)
	if not a.concentration.is_empty() and amount>0:
		a.concentration_checks.append({"dc":maxi(10,int(amount/2.0))})
		w.log_line(a.name+" has a pending concentration save on their sheet.",[a.id])
func recover(a: Dictionary,rest: String):
	ensure(a)
	for feature in a.features:
		if feature.recharge==rest or (rest=="long" and feature.recharge=="short"):feature.remaining=feature.max
	for e in a.known_spells:
		if e.has("uses_max") and (e.get("recharge","long")==rest or (rest=="long" and e.get("recharge","long")=="short")):e.uses=e.uses_max
	if base_class(a)=="Warlock":a.slots=a.slots_max.duplicate()

func concentration_roll(a: Dictionary,chosen_mode: int):
	if a.get("concentration_checks",[]).is_empty():return
	var task=a.concentration_checks.pop_front()
	if a.concentration.is_empty():return
	var roll=save_roll(a,2,chosen_mode);var success=roll.total>=int(task.dc)
	w.log_line(a.name+" · concentration CON save "+str(roll.total)+" vs DC "+str(task.dc)+(" · kept" if success else " · lost"),[a.id])
	w.encounter.outcome("save",a,a,"Concentration",("KEPT" if success else "LOST")+" · CON "+str(roll.total)+" vs DC "+str(task.dc),{"success":success})
	if not success:end_concentration(a)
