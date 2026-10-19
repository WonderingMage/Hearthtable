extends SceneTree
var w
var passed=0
var failed=0
var a
var foe
func _initialize():call_deferred("run")
func check(value: bool,note: String):
	if value:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func fixture():
	w.command("new_campaign",{"heroes":false});var loadouts=w.read_json("res://assets/loadouts.json",{})
	a=loadouts.Fighter.duplicate(true);a.id="hero";a.scene=w.data.scene;a.x=1;a.y=2;a.hp=100;a.max_hp=100;a.speed=30;a.initiative_bonus=40;a.owner=2
	foe=a.duplicate(true);foe.id="foe";foe.name="Orc";foe.hero=false;foe.owner=1;foe.x=15;foe.y=2;foe.initiative_bonus=-10;foe.hp=500;foe.max_hp=500
	w.data.actors=[a,foe];w.peers[2]={"name":"Test player"};w.mark_changed()
func run():
	await process_frame;w=root.get_node("World");fixture()
	check(w.director.enabled(),"Automatic encounters default on for existing and new campaigns")
	w.command("initiative");check(w.data.combat.active and a.initiative>=41 and a.initiative<=60,"Initiative rolls d20 plus the sheet modifier")
	check(w.encounter.active().id==a.id,"Turn order sorts descending by initiative")
	check(w.data.dice_rolls.size()==2 and w.data.dice_rolls[0].dice.size()==1,"Every combatant gets a structured visible initiative roll")
	var rolls=w.data.dice_rolls.size();w.command("initiative");check(w.data.dice_rolls.size()==rolls,"Repeated initiative cannot reroll an active encounter")
	w.apply_command("move",{"id":a.id,"x":4,"y":2},2);check(a.x==4 and a.moved==15,"A first move spends 15 feet")
	w.apply_command("move",{"id":a.id,"x":7,"y":2},2);check(a.x==7 and a.moved==30,"Split movement spends a cumulative 30 feet")
	w.apply_command("move",{"id":a.id,"x":8,"y":2},2);check(a.x==7 and a.moved==30,"The 31st foot is rejected by the host")
	w.apply_command("move",{"id":a.id,"x":8,"y":2,"dm_override":true},2);check(a.x==7,"A client cannot forge the DM movement override")
	w.apply_command("combat_action",{"id":a.id,"action":"Dash"},2);w.apply_command("move",{"id":a.id,"x":13,"y":2},2);check(a.x==13 and a.moved==60 and a.action,"Dash spends an action and adds exactly one speed budget")
	w.apply_command("move",{"id":a.id,"x":14,"y":2},2);check(a.x==13,"Dash movement cannot exceed 60 feet for a speed-30 hero")
	w.command("next_turn");w.apply_command("move",{"id":a.id,"x":12,"y":2},2);check(a.x==13,"A player cannot move during the enemy turn")
	w.command("next_turn");check(a.moved==0 and a.dash_ft==0 and not a.action,"Turn start resets movement, Dash and action resources")
	a.speed=25;w.apply_command("move",{"id":a.id,"x":7,"y":2},2);check(a.x==13,"A listed speed of 25 is honored")
	a.speed=40;w.apply_command("move",{"id":a.id,"x":5,"y":2},2);check(a.x==5 and a.moved==40,"A listed speed of 40 retains its rules-correct budget")
	fixture();foe.x=2;var hp=foe.hp;w.apply_command("attack",{"id":a.id,"target":foe.id},2)
	check(w.data.combat.active and foe.hp==hp and not a.action,"Opening attack rolls initiative before any damage or action spend")
	check(w.data.dice_rolls.size()==2,"Opening attack rolls initiative exactly once")
	w.apply_command("attack",{"id":a.id,"target":foe.id},2);check(a.action and w.data.dice_rolls.size()>2,"Attacker can confirm an attack on its legal turn with visible dice")
	fixture();foe.x=2;foe.initiative_bonus=80;a.initiative_bonus=-40;hp=foe.hp;w.apply_command("attack",{"id":a.id,"target":foe.id},2);w.apply_command("attack",{"id":a.id,"target":foe.id},2)
	check(w.encounter.active().id==foe.id and foe.hp==hp and not a.action,"An instigator who loses initiative cannot take a free first hit")
	fixture();foe.x=10;w.apply_command("move",{"id":a.id,"x":14,"y":2},2)
	check(w.COMBAT.distance(a,foe,w.scene())==15 and w.data.combat.active,"A long exploration route stops at the first 15-foot hostile alert square")
	check(a.moved==0,"Exploration movement is not charged again to the first combat turn")
	var event_id=w.data.combat.intro.id;w.apply_command("move",{"id":a.id,"x":8,"y":2},2);check(w.data.combat.intro.id==event_id,"Subsequent moves never restart initiative")
	fixture();foe.x=4
	for y in int(w.scene().height):w.scene().tiles["3,"+str(y)]=3
	w.BUILD.invalidate();check(not w.director.proximity(a),"Walls block hostile proximity alerts")
	fixture();foe.x=4;foe.hidden=true;check(not w.director.proximity(a),"DM-hidden enemies do not cause proximity alerts")
	foe.hidden=false;foe.side="neutral";check(not w.director.proximity(a),"Neutral creatures do not trigger hostile proximity")
	fixture();w.command("encounter_settings",{"enabled":true,"radius":0});w.apply_command("move",{"id":a.id,"x":12,"y":2},2);check(not w.data.combat.active and a.x==12,"DM can disable proximity independently")
	fixture();w.command("encounter_settings",{"enabled":true,"radius":0});w.command("battle_zone",{"x":5,"y":1,"ex":8,"ey":4,"name":"Throne ambush","intro":"The doors slam shut."});var zone=w.scene().battle_zones[0]
	check(zone.w==4 and zone.h==4 and not zone.spent,"DM creates an armed rectangular battle boundary")
	var snapshot=w.player_snapshot(2);check(not snapshot.scenes[0].has("battle_zones"),"Zone names, coordinates and armed state never enter player snapshots")
	w.apply_command("move",{"id":a.id,"x":12,"y":2},2);check(a.x==5 and w.data.combat.active and zone.spent,"Crossing a hidden zone stops movement and fires it once")
	check(w.data.combat.intro.title=="Throne ambush" and w.data.combat.intro.text=="The doors slam shut.","Encounter introduction publishes only when the boundary is crossed")
	w.command("end_combat");w.apply_command("move",{"id":a.id,"x":2,"y":2},2);w.apply_command("move",{"id":a.id,"x":7,"y":2},2);check(not w.data.combat.active,"Spent battle zones do not immediately restart ended combat")
	w.command("battle_zone",{"op":"rearm","id":zone.id});w.apply_command("move",{"id":a.id,"x":2,"y":2},2);w.apply_command("move",{"id":a.id,"x":7,"y":2},2);check(w.data.combat.active,"DM can rearm a battle boundary")
	w.command("end_combat");w.command("battle_zone",{"op":"toggle","id":zone.id});w.command("battle_zone",{"op":"rearm","id":zone.id});w.apply_command("move",{"id":a.id,"x":2,"y":2},2);w.apply_command("move",{"id":a.id,"x":7,"y":2},2);check(not w.data.combat.active,"Disabled zones stay inert")
	var count=w.scene().battle_zones.size();w.apply_command("battle_zone",{"x":1,"y":1,"ex":2,"ey":2},2);check(w.scene().battle_zones.size()==count,"Players cannot author DM battle zones")
	foe.hidden=true;w.command("initiative");snapshot=w.player_snapshot(2);check(snapshot.dice_rolls.all(func(e):return e.actor!=foe.id),"Hidden creatures' dice stay private in multiplayer snapshots")
	w.command("next_turn");snapshot=w.player_snapshot(2);check(not snapshot.log.any(func(e):return e.text.contains(foe.name)),"Hidden turn announcements do not leak enemy names through the public log")
	check(snapshot.combat.order.has(a.id) and not snapshot.combat.order.has(foe.id),"Hidden initiative entries stay private")
	w.command("lighting",{"time":"Night","brightness":.9,"sun_angle":45});check(w.scene().lighting.time=="Night" and w.valid_campaign(w.data),"Night lighting persists in valid campaign data")
	w.apply_command("lighting",{"time":"Day"},2);check(w.scene().lighting.time=="Night","Players cannot change the DM's time of day")
	check(w.player_snapshot(2).scenes[0].lighting.time=="Night","Scene lighting is synchronized to player snapshots")
	var package=w.SCENE_FILES.package_scene(w,w.data.scene);var imported=w.SCENE_FILES.import_package(w,package);check(imported.ok and not imported.scene.battle_zones[0].spent and imported.scene.lighting.time=="Night","Scene packages preserve lighting and rearm imported battle zones")
	var broken=w.data.duplicate(true);broken.scenes[0].battle_zones[0].w=999999;check(not w.valid_campaign(broken),"Campaign validation rejects malformed battle geometry")
	fixture();w.command("initiative");w.scene().grid_metric="5105";w.apply_command("move",{"id":a.id,"x":2,"y":3},2);w.apply_command("move",{"id":a.id,"x":3,"y":4},2);check(a.moved==15,"Optional alternating diagonal costs persist across split moves")
	fixture();foe.x=20;w.apply_command("attack",{"id":a.id,"target":foe.id},2);check(not w.data.combat.active,"An invalid out-of-range attack does not start combat")
	fixture();a.class="Wizard";a.known_spells=[];a.slots=[2,0,0,0,0,0,0,0,0];a.slots_max=a.slots.duplicate();foe.x=3;w.magic.ensure(a);a.known_spells.append({"key":"magicmissile","name":"Magic Missile","prepared":true});var slots=a.slots[0];var hp_spell=foe.hp
	w.apply_command("cast_spell",{"id":a.id,"spell":"magicmissile","slot":1,"targets":[foe.id,foe.id,foe.id],"components":true},2)
	check(w.data.combat.active and a.slots[0]==slots and foe.hp==hp_spell,"An opening hostile spell rolls initiative before slot spend or damage")
	w.apply_command("cast_spell",{"id":a.id,"spell":"magicmissile","slot":1,"targets":[foe.id,foe.id,foe.id],"components":true},2)
	check(a.slots[0]==slots-1 and foe.hp<hp_spell and a.action,"Confirming the spell on its turn spends exactly one slot and action")
	check(w.data.dice_rolls.any(func(e):return e.label=="Magic Missile · damage" and e.sides==4),"Spell damage publishes the actual damage die")
	fixture();foe.x=4
	for y in int(w.scene().height):w.scene().tiles["3,"+str(y)]=3
	w.scene().tiles["3,2"]=6;w.mark_changed();check(not w.director.proximity(a),"A closed door blocks proximity detection")
	w.command("door",{"x":3,"y":2});check(w.data.combat.active,"Opening a door onto nearby hostiles starts initiative")

	print("DIRECTOR_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
