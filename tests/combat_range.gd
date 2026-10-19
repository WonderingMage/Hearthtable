extends SceneTree
const C=preload("res://scripts/combat_rules.gd")
var w
var loadouts
var a
var b
var passed=0
var failed=0
func check(value: bool,description: String):
	if value:passed+=1;print("PASS "+description)
	else:failed+=1;push_error("FAIL "+description)
func _initialize():call_deferred("run")
func fixture(weapon: String="Longsword"):
	w.command("new_campaign",{"heroes":false});w.encounter.ensure_data();w.data.automation.auto_initiative=false;w.command("resize",{"width":60,"height":20})
	a=loadouts.Fighter.duplicate(true);b=loadouts.Fighter.duplicate(true)
	a.id="attacker";a.name="Attacker";a.weapon=weapon;a.scene=w.data.scene;a.x=2;a.y=5;a.damage="1d6+3";a.action=false
	b.id="target";b.name="Victim";b.hero=false;b.scene=w.data.scene;b.x=3;b.y=5;b.hp=1000;b.max_hp=1000
	w.data.actors=[a,b];w.history=[];w.mark_changed()
func assessment(index: int=0,mode: int=0) -> Dictionary:return w.attack_assessment(a,b,index,mode)
func monster(name: String) -> Dictionary:
	var m=w.monster_lookup[name];var unit=loadouts.Fighter.duplicate(true);unit.name=m.name;unit.monster_index=m.index;unit.hero=false;unit.scene=w.data.scene;unit.id="attacker";unit.x=2;unit.y=5;unit.token_size={"Large":2,"Huge":3,"Gargantuan":4}.get(str(m.size),1)
	unit.attack_profiles=C.monster_profiles(m);unit.weapon=unit.attack_profiles[0].name;unit.attack=unit.attack_profiles[0].bonus;unit.damage=unit.attack_profiles[0].damage
	return unit
func run():
	await process_frame;w=root.get_node("World");loadouts=w.read_json("res://assets/loadouts.json",{})
	fixture();b.x=4
	check(not assessment().ok and assessment().distance==10,"Sword cannot attack a target 10 ft away")
	var hp=b.hp;var log_size=w.data.log.size();var history_size=w.history.size()
	w.command("attack",{"id":a.id,"target":b.id,"ignore_range":true,"range":9999})
	check(b.hp==hp and not a.action and w.data.log.size()==log_size and w.history.size()==history_size,"Rejected attack rolls no dice, spends no action, changes no HP and adds no undo step")
	b.x=3;check(assessment().ok and assessment().distance==5,"Adjacent sword target is in 5-ft reach")
	b.y=6;check(assessment().ok and assessment().distance==5,"Default 2014 diagonals count one square")
	b.x=4;b.y=7;check(not assessment().ok and assessment().distance==10,"Two diagonal squares exceed 5-ft reach")
	w.command("grid_settings",{"distance":5,"unit":"ft","metric":"5105"})
	check(assessment().distance==15,"Alternating-diagonal house rule uses scene metric")
	w.command("grid_settings",{"distance":5,"unit":"ft","metric":"euclidean"})
	check(is_equal_approx(assessment().distance,sqrt(200.0)),"Euclidean option uses actual diagonal distance")
	w.command("grid_settings",{"distance":10,"unit":"ft","metric":"5e"});b.x=3;b.y=5
	check(not assessment().ok and assessment().distance==10,"Changing square size changes attack distance")
	w.command("grid_settings",{"distance":1.524,"unit":"m","metric":"5e"})
	check(assessment().ok and absf(assessment().distance-5)<0.00001,"Metric grid converts to feet without boundary rejection")
	fixture();a.token_size=2;b.x=4
	check(assessment().ok and assessment().distance==5,"Large attacker measured from nearest occupied square")
	check(C.distance(a,b,w.scene())==C.distance(b,a,w.scene()),"Footprint distance is symmetric")
	a.token_size=1;b.token_size=3;b.x=4;check(assessment().distance==10,"Large target measured from nearest footprint square")
	fixture();a=monster("troll");w.data.actors=[a,b];b.x=5
	check(w.attack_profiles(a).size()==2 and w.attack_profiles(a)[1].name=="Claw","Troll exposes Bite and Claw attacks")
	check(not assessment(0).ok and not assessment(1).ok,"Large troll does not gain invented 10-ft reach")
	b.x=4;check(assessment(0).ok and assessment(1).ok,"Troll Bite and Claw work at their printed 5-ft reach")
	fixture();a=monster("adult-red-dragon");w.data.actors=[a,b];b.x=6
	check(assessment(0).ok and not assessment(1).ok,"Dragon Bite 10 ft differs from Claw 5 ft")
	b.x=7;check(assessment(2).ok and not assessment(0).ok,"Dragon Tail 15 ft uses its own reach")
	a.erase("attack_profiles");a.erase("monster_index");b.x=6
	check(assessment().ok and w.attack_profiles(a)[0].reach==10,"Existing named monster sheets recover range from SRD data")
	fixture("Longbow");b.x=32
	check(assessment().ok and assessment().mode==0 and assessment().distance==150,"Longbow normal-range boundary is allowed")
	b.x=33;check(assessment().ok and assessment().mode==2,"Longbow beyond normal range uses disadvantage")
	check(assessment(0,1).mode==0,"Chosen advantage cancels automatic long-range disadvantage")
	w.command("grid_settings",{"distance":20,"unit":"ft","metric":"5e"});b.x=32
	check(assessment().ok and assessment().distance==600,"Longbow maximum-range boundary is allowed")
	b.x=33;check(not assessment().ok,"Longbow beyond maximum range is rejected")
	a.ignore_long_range=true;check(not assessment().ok,"Long-range feature exception never extends maximum distance")
	b.x=20;check(assessment().ok and assessment().mode==0,"Approved long-range feature removes disadvantage only")
	fixture("Dagger");b.x=6
	check(w.attack_profiles(a).size()==2 and not assessment(0).ok and assessment(1).ok,"Dagger offers separate melee and thrown modes")
	a.attack_type="melee";a.reach_ft=5;a.range_normal_ft=20;a.range_long_ft=60
	check(w.attack_profiles(a).size()==2 and assessment(1).ok,"Editing a dagger's primary profile preserves thrown mode")
	b.x=7;check(assessment(1).mode==2,"Thrown dagger uses its 20/60 range bands")
	b.x=15;check(not assessment(1).ok,"Thrown dagger cannot exceed 60 ft")
	fixture("Ray of Frost");b.x=14
	check(assessment().ok and assessment().distance==60,"Recognized ranged spell attack uses SRD range")
	b.x=15;check(not assessment().ok,"Single-range spell attack has no invented long range")
	fixture("Longbow");b.x=10
	var enemy=loadouts.Fighter.duplicate(true);enemy.id="nearby";enemy.hero=false;enemy.scene=w.data.scene;enemy.x=2;enemy.y=6;w.data.actors.append(enemy)
	check(assessment().mode==2,"Nearby hostile imposes ranged disadvantage even when shooting another target")
	enemy.conditions=["Blinded"];check(assessment().mode==0,"Blinded nearby hostile does not impose close-range disadvantage")
	enemy.conditions=["Incapacitated"];check(assessment().mode==0,"Incapacitated nearby hostile does not impose close-range disadvantage")
	enemy.conditions=[];enemy.side="neutral";check(assessment().mode==0,"Neutral creature is not treated as a hostile threat")
	enemy.side="hostile";a.ignore_close_range=true;check(assessment().mode==0,"Approved close-range feature exception is honored")
	a.ignore_close_range=false;w.scene().tiles["2,6"]=3;check(assessment().mode==0,"Hostile behind solid terrain cannot threaten by sight")
	fixture();b.x=3;w.scene().tiles["3,5"]=3
	check(not assessment().ok,"Target embedded in solid wall cannot be directly attacked")
	fixture("Longbow");b.x=8;w.scene().tiles["5,5"]=3
	check(not assessment().ok and assessment().reason.contains("blocks"),"Wall blocks an otherwise in-range attack")
	w.scene().tiles["5,5"]=6;check(not assessment().ok,"Closed door blocks an attack")
	w.command("door",{"x":5,"y":5});check(assessment().ok,"Opening door permits an unobstructed attack")
	fixture("Whip");b.x=4;b.conditions=["Prone"]
	check(assessment().mode==2,"Prone target beyond 5 ft imposes disadvantage even with a reach weapon")
	b.x=3;check(assessment().mode==1,"Prone target within 5 ft grants advantage")
	a.conditions=["Poisoned","Restrained"];check(assessment().mode==0,"Any advantage and disadvantage cancel regardless of source count")
	a.conditions=["Stunned"];check(not assessment().ok,"Incapacitated attacker cannot roll an attack")
	a.conditions=[];b.conditions=["Paralyzed"]
	check(assessment().critical_on_hit and assessment().mode==1,"Hit on paralyzed target within 5 ft is critical")
	b.x=4;check(assessment().ok and not assessment().critical_on_hit,"Reach hit beyond 5 ft is not automatically critical")
	b.conditions=["Stunned"];check(assessment().mode==1 and not assessment().critical_on_hit,"Stunned target grants advantage without automatic critical")
	fixture("Lance");check(assessment().mode==2,"Lance has disadvantage within 5 ft")
	b.x=4;check(assessment().ok and assessment().mode==0,"Lance works normally at 10 ft")
	fixture("Uncatalogued Tentacle");check(not assessment().ok and assessment().reason.contains("Configure"),"Unknown custom attack requires range configuration")
	check(C.standard("Longsword",5,"1d8+3","Reach: 10 ft")[0].reach==10,"Printed custom reach overrides a standard weapon default")
	check(C.standard("Longbow",5,"1d8+3","Range (120/480)")[0].long==480,"Printed custom bow range overrides standard range")
	a.attack_type="melee";a.reach_ft=10;b.x=4;check(assessment().ok,"Explicit custom reach enables the configured attack")
	check(not assessment(999).ok,"Invalid or forged attack index is rejected")
	fixture();a.elevation_ft=10;check(not assessment().ok and assessment().distance==10,"Elevation in feet contributes to grid attack distance")
	fixture();b.conditions=["Unconscious"];b.hp=0;b.hero=true;b.ac=1;a.attack=100;a.damage="1d2";seed(100)
	w.command("attack",{"id":a.id,"target":b.id})
	check(w.data.log.any(func(line):return line.text.contains("CRITICAL!")) and b.death_failure==2,"Close hit against unconscious hero causes critical damage and two death failures")
	fixture();b.x=8;a.owner=42;w.peers[42]=true;hp=b.hp
	w.apply_command("attack",{"id":a.id,"target":b.id,"ignore_range":true,"reach":1000},42)
	check(b.hp==hp and not a.action,"Host rejects out-of-range player requests regardless of supplied range")
	w.peers={}
	var unknown=[];var count=0
	for m in w.monsters:
		for p in C.monster_profiles(m):
			count+=1
			if not p.known:unknown.append(m.name+" / "+p.name)
	check(count>500,"SRD audit covers every individual attack, including alternate ranged modes")
	check(unknown.is_empty(),"All SRD attack rolls have parsed reach/range: "+str(unknown))
	print("COMBAT_RANGE_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
