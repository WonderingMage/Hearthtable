extends SceneTree
var w
var passed=0
var failed=0
var last_error=""
func _initialize():call_deferred("run")
func check(value: bool,note: String):
	if value:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func spell(a: Dictionary,name: String,targets: Array=[],slot: int=-1,extra: Dictionary={}) -> Dictionary:
	var k=w.magic.key(name);var s=w.spell_lookup[k]
	if w.magic.entry(a,k).is_empty():a.known_spells.append({"key":k,"name":name,"prepared":true})
	w.magic.entry(a,k).prepared=true
	var p={"id":a.id,"spell":k,"slot":int(s.level) if slot<0 else slot,"targets":targets,"components":true,"area_confirmed":true}
	p.merge(extra,true);return p
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.data.get("automation",{}).merge({"auto_initiative":false},true);w.command("new_campaign",{"heroes":false});w.encounter.ensure_data();w.data.automation.auto_initiative=false;w.data.automation.auto_saves=false
	w.message.connect(func(text):last_error=text)
	var loadouts=w.read_json("res://assets/loadouts.json",{})
	var a=loadouts.Wizard.duplicate(true);a.id="mage";a.scene=w.data.scene;a.x=2;a.y=2;a.level=5;a.hp=100;a.max_hp=100;a.slots=[4,3,2,0,0,0,0,0,0];a.slots_max=a.slots.duplicate()
	var b=loadouts.Fighter.duplicate(true);b.id="target";b.scene=w.data.scene;b.x=3;b.y=2;b.hp=500;b.max_hp=500;b.hero=false;b.ac=-100
	w.data.actors=[a,b];w.mark_changed()
	var imported=a.duplicate(true);imported.erase("known_spells");imported.spellbook=[{"name":"Magic Missile","prepared":""},{"name":"Shield","prepared":"P"},{"name":"Fire Bolt","prepared":""}];w.magic.ensure(imported)
	check(not w.magic.entry(imported,"magicmissile").prepared and w.magic.entry(imported,"shield").prepared and w.magic.entry(imported,"firebolt").prepared,"Imported prepared/unprepared marks and cantrips are respected")
	check(a.known_spells.size()>0,"Caster receives a usable starter spellbook")
	check(w.magic.formula(w.spell_lookup.firebolt,a,0)=="2d10","Cantrip damage scales by character level")
	check(w.magic.formula(w.spell_lookup.curewounds,a,2,true).begins_with("2d8"),"Healing upcast formula includes ability modifier")
	for s in w.spells:
		if w.magic.mode(s) in ["attack","save","heal","volley"] and s.index!="magic-missile":
			var formula=w.magic.formula(s,a,int(s.level),w.magic.mode(s)=="heal")
			check(w.RULES.roll(formula).ok,"Automated formula: "+s.name)
	var p=spell(a,"Magic Missile",[b.id,b.id,b.id]);var before=b.hp
	w.command("cast_spell",p)
	check(a.slots[0]==3 and b.hp<before and before-b.hp>=6 and before-b.hp<=15,"Magic Missile ticks one slot and resolves all darts")
	var history=w.history.size();var logs=w.data.log.size();var hp=b.hp
	b.x=40;w.command("cast_spell",p)
	check(a.slots[0]==3 and b.hp==hp and w.history.size()==history and w.data.log.size()==logs and last_error.contains("outside"),"Out-of-range cast spends no slot, roll, history or HP")
	b.x=3;w.scene().tiles["3,2"]=3;w.command("cast_spell",p)
	check(a.slots[0]==3 and last_error.contains("wall"),"Walls block direct spell targeting")
	w.scene().tiles={};p.targets=[b.id];w.command("cast_spell",p)
	check(a.slots[0]==3 and last_error.contains("exactly"),"All darts must be allocated before spending a slot")
	p.targets=[b.id,b.id,b.id,b.id];p.slot=2;w.command("cast_spell",p)
	check(a.slots[1]==2,"Upcasting spends the selected higher-level slot")
	var e=spell(a,"Eldritch Blast",[b.id,b.id]);before=a.slots.duplicate();w.command("cast_spell",e)
	check(a.slots==before and w.magic.count(w.spell_lookup.eldritchblast,a,0)==2,"Cantrip beams scale without spending slots")
	var bless=spell(a,"Bless",[a.id]);w.command("cast_spell",bless)
	check(a.concentration.get("spell","")=="Bless" and a.conditions.has("Concentrating"),"Casting starts concentration")
	a.temp=20;w.apply_damage(a,6,false)
	check(a.concentration_checks.size()==1 and a.concentration_checks[0].dc==10,"Temporary HP damage queues concentration save")
	w.command("cast_spell",spell(a,"Shield of Faith",[a.id]))
	check(a.concentration.spell=="Shield of Faith" and a.concentration_checks.is_empty(),"New concentration replaces old and clears its pending checks")
	w.command("condition",{"id":a.id,"condition":"Incapacitated"})
	check(a.concentration.is_empty() and not a.conditions.has("Concentrating"),"Incapacitation ends concentration")
	a.conditions=[];a.hp=100;a.slots[0]=4
	w.command("initiative");w.data.combat.order=[a.id,b.id];w.data.combat.turn=0;a.action=false;a.bonus=false
	w.command("cast_spell",spell(a,"Healing Word",[a.id]))
	var slots=a.slots[0];w.command("cast_spell",spell(a,"Magic Missile",[b.id,b.id,b.id]))
	check(a.slots[0]==slots and last_error.contains("bonus-action"),"2014 bonus-action spell rule rejects another leveled spell this turn")
	w.command("cast_spell",spell(a,"Fire Bolt",[b.id]))
	check(a.action and a.bonus,"An action cantrip remains legal after a bonus-action spell")
	w.command("next_turn");w.command("cast_spell",spell(a,"Fire Bolt",[b.id]));check(last_error.contains("Wait"),"Action spells require the caster’s turn")
	w.command("next_turn");check(not a.action and not a.bonus,"Start of turn resets spell action resources")
	w.command("cast_spell",spell(a,"Magic Missile",[b.id,b.id,b.id]));a.bonus=false
	w.command("cast_spell",spell(a,"Healing Word",[a.id]));check(last_error.contains("non-cantrip"),"Bonus-action rule also applies when leveled action spell was cast first")
	w.command("end_combat");a.slots[0]=0
	w.command("cast_spell",spell(a,"Detect Magic",[],1,{"ritual":true}))
	check(a.slots[0]==0 and a.concentration.get("spell","")=="Detect Magic","Eligible ritual spends no slot")
	w.command("cast_spell",spell(a,"Magic Missile",[b.id,b.id,b.id]));check(last_error.contains("No level"),"Exhausted slots cannot cast")
	a.slots[0]=2;var unprepared=spell(a,"Cure Wounds",[a.id]);w.magic.entry(a,"curewounds").prepared=false
	w.command("cast_spell",unprepared);check(last_error.contains("Prepare") and a.slots[0]==2,"Unprepared leveled spells cannot cast")
	b.hero=true;b.hp=500
	w.command("cast_spell",spell(a,"Sacred Flame",[b.id]));check(b.pending_saves.size()==1 and b.hp==500,"Player saving throw waits on the target’s sheet")
	w.command("spell_save",{"id":b.id});check(b.pending_saves.is_empty(),"Target can resolve their pending saving throw")
	w.command("feature_set",{"id":a.id,"name":"Test feature","max":2,"remaining":2,"recharge":"short"})
	var index=a.features.size()-1;w.command("feature_use",{"id":a.id,"index":index,"amount":2})
	check(a.features[index].remaining==0,"Limited feature uses tick off")
	w.command("feature_use",{"id":a.id,"index":index});check(a.features[index].remaining==0,"Cannot overspend feature uses")
	w.command("finish_short_rest",{"id":a.id});check(a.features[index].remaining==2,"Short rest restores eligible feature counters")
	w.peers[42]={"name":"Alice"};a.owner=42
	before=a.slots.duplicate();w.apply_command("cast_spell",spell(b,"Magic Missile",[a.id,a.id,a.id]),42)
	check(a.slots==before,"Player cannot cast another character’s spells")
	var snapshot=w.player_snapshot(42)
	check(snapshot.scenes.size()==1 and snapshot.scenes[0].id==w.data.scene,"Only the active scene is sent to players")
	check(snapshot.actors.filter(func(t):return t.id==b.id)[0].known_spells.is_empty(),"Other character’s private spellbook is omitted")
	w.peers={};a.slots[0]=0
	var innate=spell(a,"Magic Missile",[b.id,b.id,b.id]);w.command("spell_useset",{"id":a.id,"spell":"magicmissile","max":1,"uses":1,"recharge":"long"});innate.free_use=true
	w.command("cast_spell",innate);check(a.slots[0]==0 and w.magic.entry(a,"magicmissile").uses==0,"Innate casting spends its own use without a slot")
	w.command("cast_spell",innate);check(last_error.contains("No innate"),"Cannot overspend innate casting uses")
	w.command("long_rest",{"id":a.id});check(w.magic.entry(a,"magicmissile").uses==1,"Long rest restores eligible innate spell uses")
	for i in 3:w.command("inventory_item",{"id":a.id,"item":{"name":"Magic item "+str(i),"attuned":true}})
	w.command("inventory_item",{"id":a.id,"item":{"name":"Fourth item","attuned":true}})
	check(a.inventory_items.size()==3 and last_error.contains("at most 3"),"Equipment tracks the standard three-item attunement limit")
	w.command("coins",{"id":a.id,"gp":125});check(a.coins.gp==125,"Character purse is persistent and editable")
	w.scene().width=60;b.x=35;b.y=2;a.slots[2]=2
	var fireball=spell(a,"Fireball",[b.id],3,{"origin_x":32,"origin_y":2})
	check(w.magic.assessment(a,fireball).ok,"Area targets may extend beyond caster range when origin is in range")
	fireball.origin_x=34;check(not w.magic.assessment(a,fireball).ok,"Area origin cannot exceed spell range")
	fireball.origin_x=30;b.x=36;check(not w.magic.assessment(a,fireball).ok,"Area target must be within spell extent from origin")
	b.x=3;a.prepared_limit=0;var known=w.magic.entry(a,"curewounds");known.prepared=false
	w.command("prepare_spell",{"id":a.id,"spell":"curewounds"});check(not known.prepared and last_error.contains("limit"),"Preparation limit blocks excess leveled spells")
	check(w.valid_campaign(w.data),"Extended character sheets still validate and serialize")
	var json=w.normalize_numbers(JSON.parse_string(JSON.stringify(w.data)));check(w.valid_campaign(json),"Spell/resource state survives a campaign JSON round trip")
	print("MAGIC_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
