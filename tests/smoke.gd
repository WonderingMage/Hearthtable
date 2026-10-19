extends SceneTree
var passed=0
var failed=0
func check(value: bool,description: String):
	if value:passed+=1;print("PASS "+description)
	else:failed+=1;push_error("FAIL "+description)
func _initialize():call_deferred("run")
func run():
	await process_frame
	var w=root.get_node("World");w.encounter.ensure_data();w.data.automation.auto_initiative=false
	w.data=w.read_json("res://assets/starter.json",{});w.encounter.ensure_data();w.data.automation.auto_initiative=false
	var r=load("res://scripts/rules.gd")
	check(w.valid_campaign(w.data),"Starter validates")
	check(w.spells.size()==319,"319 original SRD spells")
	check(w.monsters.size()==334,"334 original SRD creatures")
	check(r.modifier(9)==-1 and r.modifier(8)==-1 and r.modifier(20)==5,"Ability modifier rounds down")
	check(r.proficiency(1)==2 and r.proficiency(5)==3 and r.proficiency(17)==6,"2014 proficiency progression")
	check(r.distance(Vector2i(1,1),Vector2i(4,5))==20,"2014 grid diagonals")
	check(not r.roll("99d6").ok and not r.roll("1d1").ok and not r.roll("hello").ok,"Dice reject invalid expressions")
	for i in 100:
		var d=r.roll("2d6+3");check(d.total>=5 and d.total<=15,"Dice bounded "+str(i))
	check(r.roll("1",true).total==1 and r.roll("1",true).dice.is_empty(),"Fixed damage remains fixed on critical")
	var crit=r.roll("2d6+3",true)
	check(crit.dice.size()==4 and crit.bonus==3,"Critical doubles dice, not modifier")
	var a=w.actor("hero1");var target=w.actor("foe0")
	w.command("move",{"id":a.id,"x":8,"y":9});check(a.x==8 and a.y==9,"Move token")
	w.undo();a=w.actor("hero1");check(a.x==5,"Undo token movement")
	w.command("hp",{"id":a.id,"amount":-5});check(a.hp==7,"Apply damage")
	w.command("temp",{"id":a.id,"amount":4});w.command("hp",{"id":a.id,"amount":-6});check(a.hp==5 and a.temp==0,"Temporary HP absorbs first")
	w.command("hp",{"id":a.id,"amount":100});check(a.hp==a.max_hp,"Healing caps at maximum")
	w.command("hp",{"id":a.id,"amount":-12});check(a.hp==0 and a.conditions.has("Unconscious"),"Zero HP unconscious")
	w.command("hp",{"id":a.id,"amount":-1});check(a.death_failure==1,"Damage at zero causes death failure")
	w.command("hp",{"id":a.id,"amount":2});check(a.hp==2 and a.death_failure==0 and not a.conditions.has("Unconscious"),"Healing resets death saves")
	w.command("hp",{"id":a.id,"amount":-99});check(a.dead and a.hp==0,"Massive damage instant death")
	w.command("hp",{"id":a.id,"amount":20});check(a.hp==0,"Ordinary healing cannot revive dead")
	w.reset_starter();w.data.get("automation",{}).merge({"auto_initiative":false},true);a=w.actor("hero1")
	w.command("condition",{"id":a.id,"condition":"Poisoned"});check(a.conditions.has("Poisoned"),"Condition toggle on")
	w.command("condition",{"id":a.id,"condition":"Poisoned"});check(not a.conditions.has("Poisoned"),"Condition toggle off")
	w.command("initiative");check(w.data.combat.active and w.data.combat.order.size()==7,"Initiative includes current visible combatants")
	var order=w.data.combat.order
	var descending=true
	for i in range(1,order.size()):descending=descending and w.actor(order[i-1]).initiative>=w.actor(order[i]).initiative
	check(descending,"Initiative sorted")
	w.command("next_turn");check(w.data.combat.turn==1,"Advance turn")
	w.command("end_combat");check(not w.data.combat.active,"End combat")
	var wizard=w.actor("hero4")
	w.command("slot",{"id":wizard.id,"level":0,"delta":-1});check(wizard.slots[0]==1,"Spend slot")
	wizard.hp=3;wizard.hit_dice=0
	w.command("long_rest",{"id":wizard.id});check(wizard.hp==8 and wizard.slots[0]==2 and wizard.hit_dice==1,"2014 long-rest recovery")
	wizard.hp=2;w.command("short_rest",{"id":wizard.id});check(wizard.hit_dice==0 and wizard.hp>=5,"Short-rest hit die")
	wizard.conditions.append("Concentrating");wizard.temp=30
	w.command("hp",{"id":wizard.id,"amount":-24})
	check(wizard.temp==6 and w.data.log.any(func(e):return e.text.contains("DC 12")),"Temporary HP damage still requires concentration save")
	wizard.hp=0;wizard.temp=5;wizard.death_failure=0
	w.command("hp",{"id":wizard.id,"amount":-1});check(wizard.death_failure==1,"Temporary HP does not prevent death failures at zero")
	w.command("template",{"id":"hero1","shape":"Circle","x":6,"y":6,"ex":8,"ey":6});check(w.scene().areas.size()==1,"Persist spell area")
	w.command("clear_templates");check(w.scene().areas.is_empty(),"Clear spell area templates")
	var snapshot=w.player_snapshot()
	check(snapshot.journal_dm=="","DM journal omitted from player snapshot")
	check(snapshot.scenes[0].dm_notes=="","Scene DM notes omitted")
	check(not snapshot.actors.any(func(unit):return unit.id=="foe2"),"Fogged enemy omitted")
	check(w.valid_campaign(snapshot),"Player snapshot validates")
	w.peers[42]=true;a=w.actor("hero1");a.owner=42
	w.apply_command("move",{"id":"hero2","x":15,"y":4},42);check(w.actor("hero2").x==6,"Players cannot move someone else's hero")
	w.apply_command("move",{"id":a.id,"x":6,"y":8},42);check(a.x==6,"Owner can move assigned hero")
	w.apply_command("hp",{"id":a.id,"amount":-5},42);check(a.hp==7,"Players can manage their own HP")
	var other_hp=w.actor("hero2").hp;w.apply_command("hp",{"id":"hero2","amount":-5},42);check(w.actor("hero2").hp==other_hp,"Players cannot edit another hero’s HP")
	w.apply_command("move",{"id":a.id,"x":17,"y":5},42);check(a.x==6,"Player cannot enter unrevealed fog")
	w.peers={}
	w.command("scene",{"scene":"crossing"});check(w.data.scene=="crossing" and a.scene=="crossing","Party scene travel")
	var path="user://test_campaign.json"
	check(w.save_campaign(path)==OK,"Atomic save succeeds")
	w.data.title="Changed";check(w.load_campaign(path) and w.data.title=="The Lantern Below","Save reload round-trip")
	w.command("campaign_name",{"title":"Backup"});w.save_campaign(path)
	check(FileAccess.file_exists(path+".bak"),"Backup written")
	var broken=w.data.duplicate(true);broken.actors[0].erase("abilities");check(not w.valid_campaign(broken),"Reject malformed sheets")
	check(w.save_campaign("/nonexistent/hearthtable/test.json")!=OK,"Failed save is reported")
	w.command("new_campaign",{"title":"Blank test","heroes":false});check(w.data.title=="Blank test" and w.data.actors.is_empty() and w.data.scenes.size()==1,"Create fresh empty campaign")
	w.undo();check(w.data.title=="Backup","Undo new campaign restores prior table")
	print("RESULT "+str(passed)+" passed, "+str(failed)+" failed")
	quit(1 if failed else 0)
