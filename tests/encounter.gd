extends SceneTree
var w
var passed=0
var failed=0
var rejection=""
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func cast(a: Dictionary,name: String,targets: Array=[],extra: Dictionary={}):
	var key=w.COMBAT.key(name);var s=w.spell_lookup[key]
	if w.magic.entry(a,key).is_empty():a.known_spells.append({"key":key,"name":name,"prepared":true})
	w.magic.entry(a,key).prepared=true
	var p={"id":a.id,"spell":key,"slot":int(s.level),"targets":targets,"components":true,"area_confirmed":true};p.merge(extra,true);w.command("cast_spell",p)
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.data.get("automation",{}).merge({"auto_initiative":false},true);w.command("new_campaign",{"heroes":false});w.encounter.ensure_data();w.data.automation.auto_initiative=false;w.message.connect(func(text):rejection=text)
	var loadouts=w.read_json("res://assets/loadouts.json",{});var a=loadouts.Fighter.duplicate(true);a.id="hero";a.scene=w.data.scene;a.x=2;a.y=2;a.level=5;a.hp=100;a.max_hp=100
	var b=loadouts.Wizard.duplicate(true);b.id="mage";b.scene=w.data.scene;b.x=4;b.y=2;b.hp=500;b.max_hp=500;b.slots=[10,10,10,10,10,10,10,10,10];b.slots_max=b.slots.duplicate()
	var foe=a.duplicate(true);foe.id="foe";foe.hero=false;foe.x=3;foe.y=2;foe.hp=1000;foe.max_hp=1000;foe.ac=-20
	w.data.actors=[a,b,foe];w.mark_changed()
	check(w.data.automation.auto_saves and w.data.automation.strict_turns,"Streamlined automation defaults are enabled")
	check(w.encounter.chance(5,15)==55,"Hit chance enumerates natural 1/20 correctly")
	check(w.encounter.chance(5,15,1)==80 and w.encounter.chance(5,15,2)==30,"Advantage and disadvantage probabilities are correct")
	check(w.encounter.chance(100,1)==95 and w.encounter.chance(-100,100)==5,"Hit chances retain automatic miss/critical boundaries")
	check(w.encounter.attacks(a)==2,"Fighter level 5 has two attacks per action")
	a.class_levels={"Fighter":3,"Rogue":2};check(w.encounter.attacks(a)==1,"Extra Attack uses class level rather than total multiclass level");a.erase("class_levels")
	w.command("initiative");w.data.combat.order=[a.id,b.id,foe.id];w.data.combat.turn=0
	w.command("attack",{"id":a.id,"target":foe.id});check(a.action and a.attacks_left==1,"First attack consumes action and leaves Extra Attack")
	w.command("attack",{"id":a.id,"target":foe.id});var hp=foe.hp;check(a.attacks_left==0,"Second attack consumes remaining attack budget")
	var history=w.history.size();w.command("attack",{"id":a.id,"target":foe.id});check(foe.hp==hp and w.history.size()==history and rejection.contains("Action spent"),"Extra attack beyond budget has no effects")
	w.command("attack",{"id":b.id,"target":foe.id});check(rejection.contains("Wait"),"Out-of-turn weapon attacks are rejected")
	w.command("feature_set",{"id":a.id,"name":"Action Surge","max":1,"remaining":1,"recharge":"short"});var surge=a.features.size()-1
	w.command("feature_use",{"id":a.id,"index":surge});check(a.extra_actions==1,"Action Surge grants an additional action")
	w.command("attack",{"id":a.id,"target":foe.id});check(a.extra_actions==0 and a.attacks_left==1,"Surged Attack action opens another Extra Attack sequence")
	w.command("next_turn");check(w.encounter.active().id==b.id,"Turn advancement selects the next actor")
	w.command("combat_action",{"id":a.id,"action":"Dash"});check(rejection.contains("active turn"),"Combat actions cannot be used out of turn")
	w.command("end_turn",{"id":a.id});check(w.encounter.active().id==b.id,"A player cannot end someone else’s turn")
	w.command("combat_action",{"id":b.id,"action":"Dodge"});check(b.dodging and b.action,"Dodge spends action and grants defense state")
	var near=b.duplicate(true);near.x=3;var assessment=w.attack_assessment(a,near,0);check(assessment.disadvantage.has("Target dodging"),"Dodge feeds the same weapon roll modifiers")
	w.command("next_turn");w.command("next_turn");w.command("next_turn");check(not b.dodging,"Dodge expires at the start of the next own turn")
	w.command("end_combat");w.scene().tiles={};foe.x=15;foe.y=10;a.moved=0;a.action=false
	var route=w.encounter.movement(a,Vector2i(7,2));check(route.ok and route.cost==25,"Movement route costs actual traversed distance")
	w.scene().tiles["3,2"]=12;route=w.encounter.movement(a,Vector2i(3,2));check(route.ok and route.cost==10,"Rubble doubles movement cost")
	w.scene().tiles["3,2"]=4;check(w.encounter.movement(a,Vector2i(3,2)).cost==10,"Water uses the configured difficult-ground movement cost")
	w.scene().tiles["3,2"]=3;check(not w.encounter.movement(a,Vector2i(3,2)).ok,"Solid walls block movement")
	w.scene().tiles={};w.command("elevation",{"x":3,"y":2,"feet":10});check(not w.encounter.movement(a,Vector2i(3,2)).ok,"A sheer two-cell rise is not free walking")
	w.scene().tiles["3,2"]=11;check(w.encounter.movement(a,Vector2i(3,2)).ok,"Stairs permit a higher rise")
	w.scene().elevations={};w.scene().tiles={};w.data.combat={"active":true,"order":[a.id,b.id],"turn":0,"round":1,"serial":100};w.encounter.reset_turn(a);a.action=false;a.moved=25
	w.command("move",{"id":a.id,"x":5,"y":2});check(a.x==2 and rejection.contains("movement"),"Movement beyond the remaining budget is rejected")
	w.command("combat_action",{"id":a.id,"action":"Dash"});check(a.dash_ft==30,"Dash adds one speed to the movement budget")
	w.command("move",{"id":a.id,"x":5,"y":2});check(a.x==5 and a.moved>=40,"A legal Dash route is applied authoritatively")
	w.command("end_combat");a.x=2;a.y=2;a.hp=100;a.temp=0;a.damage_resistances=["fire"];w.apply_damage(a,11,false,"fire");check(a.hp==95,"Typed resistance halves damage rounded down")
	a.damage_immunities=["cold"];w.apply_damage(a,20,false,"cold");check(a.hp==95,"Typed immunity prevents damage")
	a.damage_vulnerabilities=["radiant"];w.apply_damage(a,7,false,"radiant");check(a.hp==81,"Typed vulnerability doubles damage")
	cast(b,"Shield");check(w.encounter.effective_ac(b)==int(b.ac)+5,"Shield changes effective AC automatically")
	var hp_before=b.hp;cast(b,"Magic Missile",[b.id,b.id,b.id]);check(b.hp==hp_before,"Shield blocks Magic Missile damage")
	w.encounter.reset_turn(b);check(w.encounter.effective_ac(b)==int(b.ac),"Shield expires at the next own turn")
	cast(b,"Bless",[a.id]);check(a.effects.any(func(e):return e.kind=="bless"),"Bless is linked to its concentration source")
	var bonus=w.encounter.bonus_die(a,"attack");check(bonus.amount>=1 and bonus.amount<=4,"Bless adds a d4 to attacks")
	w.command("end_concentration",{"id":b.id});check(not a.effects.any(func(e):return e.kind=="bless"),"Ending concentration removes linked Bless effects")
	cast(b,"Shield of Faith",[a.id]);check(w.encounter.effective_ac(a)==int(a.ac)+2,"Shield of Faith updates target AC")
	cast(b,"Guidance",[b.id]);check(w.encounter.effective_ac(a)==int(a.ac),"Replacing concentration cleans up the old target’s effect")
	bonus=w.encounter.bonus_die(b,"check",true);check(bonus.amount>=1 and b.concentration.is_empty(),"Guidance is consumed by a supported ability check")
	cast(b,"Invisibility",[b.id]);check(b.conditions.has("Invisible"),"Invisibility applies the supported condition")
	w.encounter.break_invisibility(b);check(not b.conditions.has("Invisible"),"Attacking/casting can clear granted invisibility")
	cast(b,"Sacred Flame",[a.id]);check(a.pending_saves.is_empty() and w.data.resolutions.any(func(e):return e.kind=="save"),"Automatic spell saves publish structured outcomes")
	cast(b,"Bless",[b.id]);w.apply_damage(b,4,false);check(b.concentration_checks.is_empty(),"Automatic concentration saves resolve after damage")
	w.data.automation.auto_saves=false;cast(b,"Bless",[b.id]);w.apply_damage(b,4,false);check(b.concentration_checks.size()==1,"Manual save mode remains available")
	w.command("end_concentration",{"id":b.id});w.data.automation.auto_saves=true
	var monster=w.monster_lookup.troll;var t=a.duplicate(true);t.id="troll";t.hero=false;t.class="Monster";t.name="Troll";t.monster_index="troll";t.weapon="Bite";t.attack=7;t.damage="1d6+4";t.attack_profiles=w.COMBAT.monster_profiles(monster);t.x=8;t.y=8;w.data.actors.append(t);w.mark_changed()
	check(w.encounter.multi_limits(t).get("bite",0)==1 and w.encounter.multi_limits(t).get("claw",0)==2,"Troll Multiattack resolves one Bite and two Claws")
	w.command("combat_settings",{"auto_saves":true,"strict_turns":true});w.data.combat={"active":true,"order":[t.id],"turn":0,"round":1,"serial":200};w.encounter.reset_turn(t);t.action=false
	var profile=w.attack_profiles(t)[0];w.encounter.consume_attack(t,profile);check(not w.encounter.attack_gate(t,profile).is_empty(),"A spent named Multiattack cannot substitute extra bites")
	w.command("end_combat");w.scene().tiles={"3,2":3};w.scene().wall_height_ft=10;a.x=2;a.y=2;b.x=4;b.y=2;a.elevation_ft=0;b.elevation_ft=0
	check(is_inf(w.COMBAT.clear_distance(a,b,w.scene()).distance),"Full-height walls block level attacks")
	a.elevation_ft=20;b.elevation_ft=20;check(not is_inf(w.COMBAT.clear_distance(a,b,w.scene()).distance),"Attacks above a wall’s height use the 3D clear path")
	a.elevation_ft=0;b.elevation_ft=0;w.scene().tiles={};w.scene().elevations={"3,2":10};check(is_inf(w.COMBAT.clear_distance(a,b,w.scene()).distance),"Raised solid terrain can block a lower attack")
	check(w.valid_campaign(w.data),"Enhanced combat/terrain data passes campaign validation")
	check(w.data.resolutions.size()<=30,"Shared outcome history is bounded")
	print("ENCOUNTER_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
