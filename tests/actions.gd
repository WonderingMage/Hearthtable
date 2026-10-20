extends SceneTree
var w
var a
var b
var ally
var passed=0
var failed=0
var rejection=""
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
	if ok:passed+=1;print("PASS "+text)
	else:failed+=1;push_error("FAIL "+text)
func fixture():
	w.command("new_campaign",{"heroes":false});w.encounter.ensure_data();w.data.automation.auto_initiative=false
	a=w.read_json("res://assets/loadouts.json",{}).Fighter.duplicate(true);a.id="hero";a.scene=w.data.scene;a.x=4;a.y=4;a.level=5;a.grapple_hands=1;a.skill_bonuses={"Athletics":100};a.hp=100;a.max_hp=100
	b=a.duplicate(true);b.id="foe";b.hero=false;b.x=5;b.skill_bonuses={"Athletics":-100,"Acrobatics":-99};b.hp=1000;b.max_hp=1000
	ally=a.duplicate(true);ally.id="ally";ally.x=4;ally.y=5;ally.skill_bonuses={};ally.class="Wizard"
	w.data.actors=[a,b,ally];w.data.combat={"active":true,"order":[a.id,b.id,ally.id],"turn":0,"round":1,"serial":1};w.mark_changed();rejection=""
func action(name: String,target: String="foe",extra: Dictionary={}):
	var p={"id":"hero","target":target,"action":name};p.merge(extra,true);w.command("combat_action",p)
func run():
	await process_frame;w=root.get_node("World");w.message.connect(func(value):rejection=value)
	fixture();var hp=b.hp;action("Grapple")
	check(b.conditions.has("Grappled") and a.action and a.attacks_left==1 and b.hp==hp,"Grapple replaces one Extra Attack without rolling damage")
	check(w.encounter.actions.defense_skill(b)=="Acrobatics","Defender uses the better imported final contest bonus")
	check(w.data.dice_rolls[-2].label.contains("Athletics") and w.data.dice_rolls[-1].label.contains("Acrobatics"),"Both contest dice and skill choices are visible in host outcomes")
	check(w.encounter.speed(b)==0 and not w.encounter.movement(b,Vector2i(6,4)).ok,"Grappled creature has speed zero and cannot walk")
	action("Shove prone");check(b.conditions.has("Prone") and a.attacks_left==0,"Shove prone can replace the second attack")
	var events=w.data.resolutions.size();action("Shove prone");check(w.data.resolutions.size()==events and rejection.contains("No attack"),"No third special attack can bypass the action budget")
	fixture();b.skill_bonuses={"Athletics":200};action("Grapple");check(not b.conditions.has("Grappled") and a.attacks_left==1,"Failed contest still consumes exactly one attack")
	fixture();b.x=7;events=w.data.resolutions.size();action("Grapple");check(not a.action and w.data.resolutions.size()==events,"Out-of-range grapple rejects before dice or resources")
	fixture();a.weapon="Whip";b.x=6;action("Grapple");check(not a.action,"Weapon reach does not extend grappling reach")
	fixture();b.token_size=3;b.size_category="Huge";action("Shove prone");check(not a.action,"Cannot shove a creature more than one size larger")
	fixture();a.size_category="Small";b.size_category="Large";b.token_size=2;action("Grapple");check(not a.action,"Small versus Large is rejected despite Small and Medium sharing a token footprint")
	fixture();a.grapple_hands=0;action("Grapple");check(not a.action and rejection.contains("free hand"),"No free hand rejects grappling without spending an action")
	fixture();w.scene().tiles["5,4"]=6;action("Grapple");check(not a.action,"Closed door blocks a special melee action")
	fixture();a.attack_limits_left={"bite":1};a.attacks_left=1;action("Grapple");check(not a.action and not b.conditions.has("Grappled"),"A grapple cannot replace a monster Multiattack component")
	fixture();action("Shove push");check(b.x==6 and b.y==4 and b.moved==0 and b.hp==1000,"Shove pushes exactly 5 feet away without spending target movement or HP")
	fixture();w.scene().tiles["6,4"]=3;action("Shove push");check(b.x==5 and not a.action,"Blocked push destination is refused before rolling")
	fixture();ally.x=6;ally.y=4;action("Shove push");check(not a.action,"Cannot push a creature into an occupied square")
	fixture();a.owner=88;w.apply_command("combat_action",{"id":a.id,"target":b.id,"action":"Grapple"},99);check(not a.action and not b.conditions.has("Grappled"),"Forged ownership cannot initiate a grapple")
	fixture();b.hidden=true;w.apply_command("combat_action",{"id":a.id,"target":b.id,"action":"Grapple"},int(a.owner)+1);check(not a.action,"Unowned request is refused")
	fixture();action("Grapple");a.action=false;a.attacks_left=0
	w.command("move",{"id":a.id,"x":3,"y":4});check(a.x==3 and b.x==4 and w.encounter.speed(a)==15,"Dragging moves the held creature and halves grappler speed")
	w.command("move",{"id":a.id,"x":0,"y":4});check(a.x==3,"Dragging respects the reduced cumulative movement budget")
	action("Release grapple");check(not b.conditions.has("Grappled") and w.encounter.speed(a)==30 and not a.action,"Release is free and removes only the host-created hold")
	fixture();action("Grapple");w.apply_damage(a,1000,false);w.mark_changed();check(not b.conditions.has("Grappled"),"Incapacitated grappler automatically releases its hold")
	fixture();action("Grapple");a.x=1;w.mark_changed();check(not b.conditions.has("Grappled"),"Forced separation beyond reach ends the hold")
	fixture();var other=w.scene().duplicate(true);other.id="other_scene";w.data.scenes.append(other);a.scene=other.id;b.scene=other.id;w.encounter.add_effect(b,{"kind":"grapple","source":a.id,"condition":"Grappled"});w.scene().tiles["5,4"]=3;w.mark_changed();check(b.conditions.has("Grappled"),"Inactive-scene holds use their own scene geometry during reconciliation")
	fixture();action("Grapple");w.data.combat.turn=1;b.skill_bonuses={"Acrobatics":200};w.command("combat_action",{"id":b.id,"target":a.id,"action":"Escape grapple"});check(not b.conditions.has("Grappled") and b.action,"Escape uses a full action and an opposed check")
	fixture();action("Grapple");w.data.combat.turn=1;w.command("combat_action",{"id":b.id,"target":a.id,"action":"Escape grapple"});check(b.conditions.has("Grappled") and b.action,"Failed escape spends an action and preserves the hold")
	fixture();a.skill_bonuses={"Athletics":0};b.skill_bonuses={"Athletics":0,"Acrobatics":0}
	var tie_seed=0
	for candidate in range(1,500):
		seed(candidate);var first=w.encounter.actions.roll_check(a,"Athletics");var second=w.encounter.actions.roll_check(b,"Athletics")
		if first.total==second.total:tie_seed=candidate;break
	seed(tie_seed);action("Grapple");check(tie_seed>0 and not b.conditions.has("Grappled") and a.attacks_left==1,"A tied opposed grapple leaves the target ungrappled and still spends the attack")
	fixture();action("Help attack");check(a.action and w.encounter.actions.help_attack(ally,b),"Help attack spends an action and benefits an ally against that enemy")
	check(not w.encounter.actions.help_attack(a,b),"Helper cannot benefit from its own distraction")
	var preview=w.attack_assessment(ally,b);check(preview.advantage.has("Help") and w.encounter.actions.help_attack(ally,b),"Attack preview includes Help without consuming it")
	w.data.combat.turn=2;ally.attack=-100;w.command("attack",{"id":ally.id,"target":b.id});check(not w.encounter.actions.help_attack(ally,b),"First allied attack consumes Help even on a miss")
	fixture();action("Help attack");w.encounter.reset_turn(a);check(not w.encounter.actions.help_attack(ally,b),"Unused Help expires at the start of helper's next turn")
	fixture();action("Help check","ally",{"skill":"Athletics"});check(not a.action,"Help check requires task eligibility confirmation")
	action("Help check","ally",{"skill":"Athletics","task_reviewed":true});check(w.encounter.actions.check_mode(ally,"Athletics")==1 and w.encounter.actions.check_mode(ally,"Perception")==0,"Help check grants advantage only to the selected skill")
	w.command("check",{"id":ally.id,"skill":"Perception"});check(w.encounter.actions.help_check(ally,"Athletics"),"Unrelated check preserves the assistance")
	w.command("check",{"id":ally.id,"skill":"Athletics"});check(not w.encounter.actions.help_check(ally,"Athletics"),"Actual selected skill check consumes the Help benefit")
	fixture();action("Help attack");w.encounter.add_effect(b,{"kind":"help_attack","source":ally.id,"help_until":ally.id});check(w.encounter.actions.help_attack(ally,b,true) and b.effects.size()==1,"Only assistance from a different helper applies to an attack")
	fixture();action("Help attack");w.encounter.add_effect(b,{"kind":"help_attack","source":ally.id,"help_until":ally.id});var third=ally.duplicate(true);third.id="third";w.data.actors.append(third);w.encounter.actions.help_attack(third,b,true);check(not b.effects.any(func(e):return e.kind=="help_attack"),"Multiple Help sources are consumed by the same first eligible attack rather than stacking across attacks")
	fixture();action("Help attack");w.data.combat.turn=2;ally.known_spells=[];w.magic.ensure(ally);ally.spell_attack=-100
	w.magic.spell_attack(ally,b,w.spell_lookup.firebolt,"1d10",0);check(not w.encounter.actions.help_attack(ally,b),"A spell attack also consumes Help on its first attack roll")
	fixture();action("Dodge","");check(w.encounter.actions.dodging(a),"Dodge is available through the same combat action flow")
	check(w.magic.save_roll(a,1,0).dice.size()==2,"Dodge grants advantage on Dexterity saving throws")
	var dice_before=w.data.dice_rolls.size();w.command("check",{"id":a.id,"ability":1,"save":true,"label":"DEX save"});check(w.data.dice_rolls.size()==dice_before+1 and w.data.dice_rolls[-1].dice.size()==2,"The actual sheet saving-throw command applies Dodge and records one roll")
	a.conditions.append("Grappled");w.mark_changed();check(not a.dodging and w.magic.save_roll(a,1,0).dice.size()==1,"Speed zero ends Dodge and its Dexterity save advantage")
	a.conditions.erase("Grappled");w.mark_changed();check(not w.encounter.actions.dodging(a),"Dodge does not resume after recovering speed")
	a.conditions.append("Prone");a.conditions.append("Grappled");action("Stand","");check(a.conditions.has("Prone"),"A speed-zero creature cannot stand for free")
	fixture();w.data.combat.active=false;w.data.automation.auto_initiative=true;action("Grapple");check(w.data.combat.active and not a.action and not b.conditions.has("Grappled"),"Opening hostile grapple starts initiative without a free contest")
	check(w.valid_campaign(w.data),"Action states retain schema-1 save compatibility")
	var appearance=preload("res://scripts/mini_appearance.gd").DEFAULTS.duplicate(true);appearance.style="Mage";var original_hp=a.hp
	w.command("customize_mini",{"id":a.id,"appearance":appearance,"color":"#123456","actor":{"hp":9999}});check(a.appearance.style=="Mage" and a.hp==original_hp,"Cosmetic command accepts bounded appearance data and ignores extra gameplay fields")
	appearance.height=INF;w.command("customize_mini",{"id":a.id,"appearance":appearance,"color":"#123456"});check(is_finite(a.appearance.height),"Non-finite miniature dimensions are rejected at the host boundary")
	fixture();b.hidden=true;w.encounter.add_effect(ally,{"kind":"grapple","source":b.id,"help_until":b.id,"condition":"Grappled"});var snapshot=w.player_snapshot(88);var public_ally=snapshot.actors.filter(func(unit):return unit.id==ally.id)[0]
	check(public_ally.conditions.has("Grappled") and public_ally.effects[0].source=="" and not public_ally.effects[0].has("help_until"),"Action effects preserve public conditions without leaking a hidden source's identity")
	print("ACTIONS_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
