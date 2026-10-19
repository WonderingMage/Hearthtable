extends SceneTree
var w
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func wait_for(test: Callable):
	for i in 240:
		if test.call():return true
		await create_timer(.05).timeout
	check(false,"Timed out waiting for network state");return false
func marker(word: String) -> bool:return w.data.log.any(func(e):return e.text.contains(word))
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	if OS.get_cmdline_user_args().has("--host"):
		w.command("new_campaign",{"heroes":false});var a=w.read_json("res://assets/loadouts.json",{}).Fighter.duplicate(true);a.id="hero";a.scene=w.data.scene;a.x=1;a.y=2;a.speed=30;a.initiative_bonus=50
		var b=a.duplicate(true);b.id="foe";b.name="Orc";b.hero=false;b.x=12;b.hp=1000;b.max_hp=1000;b.initiative_bonus=-50
		var secret=b.duplicate(true);secret.id="secret";secret.name="Secret watcher";secret.x=20;secret.hidden=true
		w.data.actors=[a,b,secret];w.mark_changed();w.command("encounter_settings",{"enabled":true,"radius":0});w.command("battle_zone",{"x":5,"y":1,"ex":8,"ey":4,"name":"Secret boundary","intro":"The ambush begins."});w.command("lighting",{"time":"Night"})
		check(w.host_session("director-net",24711)==OK,"DM opens encounter test server")
		await wait_for(func():return w.peers.size()==1);var peer=int(w.peers.keys()[0]);a.owner=peer;w.mark_changed()
		await wait_for(func():return w.data.combat.active and a.x==5)
		check(w.scene().battle_zones.size()==1 and w.scene().battle_zones[0].spent,"Host fires its private boundary from a remote movement request")
		check(w.data.dice_rolls.size()==3 and w.data.combat.order.size()==3,"Host rolls all combatants including a hidden creature exactly once")
		await wait_for(func():return marker("BUDGET_CHECKED"));check(a.x==11 and a.moved==30,"Host enforces the remote player's cumulative 30-foot budget")
		check(w.scene().lighting.time=="Night" and w.scene().battle_zones.size()==1,"Forged player lighting and battle-zone commands have no effect")
		while w.encounter.active().id==a.id:w.command("next_turn")
		await wait_for(func():return marker("TURN_CHECKED"));check(a.x==11,"Out-of-turn remote movement does not change position")
		w.command("end_combat");a.action=false;w.mark_changed();var hp=b.hp
		await wait_for(func():return w.data.combat.active);check(b.hp==hp and not a.action,"Remote opening attack starts initiative without spending action or damage")
		await wait_for(func():return marker("OPENING_CHECKED"));w.command("end_combat");a.x=1;b.x=10;w.command("encounter_settings",{"enabled":true,"radius":15});w.mark_changed()
		await wait_for(func():return marker("PROXIMITY_CHECKED"));check(w.data.combat.active and w.COMBAT.distance(a,b,w.scene())==15,"Host interrupts a remote exploration route at hostile proximity")
		w.apply_command("roll_d20",{},1);await wait_for(func():return marker("DICE_CHECKED"))
		print("DIRECTOR_NETWORK_HOST "+str(passed)+" passed, "+str(failed)+" failed");await create_timer(.5).timeout;quit(1 if failed else 0)
	else:
		check(w.join_session("127.0.0.1","director-net",24711,"Explorer")==OK,"Player connects to encounter host")
		await wait_for(func():return w.client and w.network_label.begins_with("Connected") and w.can_control(w.actor("hero")))
		check(not w.scene().has("battle_zones"),"Actual network snapshot contains no private battle-zone geometry")
		check(w.scene().lighting.time=="Night","Actual network snapshot carries the DM's night lighting")
		w.command("battle_zone",{"x":1,"y":1,"ex":2,"ey":2});w.command("lighting",{"time":"Day"});w.command("move",{"id":"hero","x":10,"y":2})
		await wait_for(func():return w.data.combat.active);check(w.actor("hero").x==5 and w.data.combat.intro.text=="The ambush begins.","Player is stopped at the boundary and receives the encounter introduction")
		check(w.data.dice_rolls.size()==2 and not w.data.actors.any(func(a):return a.id=="secret"),"Hidden enemy identity and initiative dice never reach the client")
		var rolls=w.data.dice_rolls.duplicate(true);check(rolls.all(func(e):return e.total==int(e.dice[0])+int(e.bonus)),"Client-visible initiative totals match the host's dice and modifiers")
		w.command("move",{"id":"hero","x":11,"y":2});await wait_for(func():return w.actor("hero").x==11)
		w.command("move",{"id":"hero","x":10,"y":2,"dm_override":true});await create_timer(.15).timeout;check(w.actor("hero").x==11 and w.actor("hero").moved==30,"Player sees an over-budget forged override rejected")
		w.command("chat",{"text":"BUDGET_CHECKED"});await wait_for(func():return w.encounter.active().get("id","")!="hero")
		w.command("move",{"id":"hero","x":10,"y":2});await create_timer(.15).timeout;check(w.actor("hero").x==11,"Player cannot move on an enemy's turn");w.command("chat",{"text":"TURN_CHECKED"})
		await wait_for(func():return not w.data.combat.active);var hp=w.actor("foe").hp;w.command("attack",{"id":"hero","target":"foe"});await wait_for(func():return w.data.combat.active)
		check(w.actor("foe").hp==hp and not w.actor("hero").action,"Opening attack never gives the remote player a free hit");w.command("chat",{"text":"OPENING_CHECKED"})
		await wait_for(func():return not w.data.combat.active and w.actor("hero").x==1);w.command("move",{"id":"hero","x":14,"y":2});await wait_for(func():return w.data.combat.active)
		check(w.COMBAT.distance(w.actor("hero"),w.actor("foe"),w.scene())==15,"Player sees proximity interrupt at the configured range");w.command("chat",{"text":"PROXIMITY_CHECKED"})
		await wait_for(func():return w.data.dice_rolls.any(func(e):return str(e.label).contains("d20")));check(w.data.dice_rolls[-1].actor=="" and w.data.dice_rolls[-1].dice.size()==1,"DM free dice rolls are visible to the player");w.command("chat",{"text":"DICE_CHECKED"})
		print("DIRECTOR_NETWORK_CLIENT "+str(passed)+" passed, "+str(failed)+" failed");await create_timer(1).timeout;quit(1 if failed else 0)
