extends SceneTree
const A=preload("res://scripts/mini_appearance.gd")
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
	if ok:passed+=1;print("PASS "+text)
	else:failed+=1;push_error("FAIL "+text)
func wait_for(test: Callable) -> bool:
	var until=Time.get_ticks_msec()+150000
	while Time.get_ticks_msec()<until:
		if test.call():return true
		await create_timer(.05).timeout
	check(false,"Network stage timed out");return false
func marker(value: String) -> bool:return w.data.log.any(func(e):return e.text.contains(value))
func chat(value: String):w.command("chat",{"text":value})
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	if OS.get_cmdline_user_args().has("--host"):await host()
	else:await client()
	await create_timer(.5).timeout;quit(1 if failed else 0)
func host():
	w.command("new_campaign",{"heroes":false});w.encounter.ensure_data();w.data.automation.auto_initiative=false
	var a=w.read_json("res://assets/loadouts.json",{}).Fighter.duplicate(true);a.id="hero";a.name="Remote hero";a.scene=w.data.scene;a.x=4;a.y=4;a.level=5;a.grapple_hands=1;a.skill_bonuses={"Athletics":100};a.hp=100;a.max_hp=100;a.appearance=A.DEFAULTS.duplicate(true)
	var b=a.duplicate(true);b.id="foe";b.hero=false;b.x=5;b.skill_bonuses={"Athletics":-100,"Acrobatics":-100};b.hp=1000;b.max_hp=1000
	var ally=a.duplicate(true);ally.id="ally";ally.owner=1;ally.y=5;ally.attack=-100;ally.background="PRIVATE CHARACTER DETAILS"
	var hidden=b.duplicate(true);hidden.id="hidden";hidden.x=5;hidden.y=5;hidden.hidden=true
	w.data.actors=[a,b,ally,hidden];w.encounter.add_effect(ally,{"kind":"grapple","source":hidden.id,"condition":"Grappled"});w.mark_changed()
	check(w.host_session("actions-net",24727,true)==OK,"Host opens character/action test lobby")
	if not await wait_for(func():return w.peers.size()==1):return
	var peer=int(w.peers.keys()[0]);a.owner=peer;w.mark_changed()
	if not await wait_for(func():return w.session.requests.has(peer)):return
	var submitted=w.session.requests[peer]
	check(submitted.name=="Network recruit" and submitted.appearance.style=="Mage","Host receives a complete reviewed character with cosmetic choices")
	check(w.data.actors.size()==4,"Player's submitted sheet is pending until DM acceptance")
	w.command("review_hero",{"peer":peer,"accept":true});var recruit=w.data.actors[-1]
	check(recruit.owner==peer and recruit.hero and recruit.appearance.style=="Mage","DM acceptance assigns the new hero and keeps customization")
	w.command("lobby_start");w.data.combat={"active":true,"order":[a.id,b.id,ally.id],"turn":0,"round":1,"serial":1};w.mark_changed()
	if not await wait_for(func():return marker("COSMETICS_CHECKED")):return
	check(a.appearance.style=="Mage" and a.color=="#abc123" and a.hp==100 and a.owner==peer,"Host applies only appearance fields from a remote cosmetic request")
	check(ally.appearance.style=="Auto" and b.appearance.style=="Auto","Forged customization of another hero or monster is refused")
	if not await wait_for(func():return marker("GRAPPLE_CHECKED")):return
	check(b.conditions.has("Grappled") and a.attacks_left==1 and b.hp==1000,"Host resolves a remote grapple with one attack and no damage")
	w.data.combat.turn=1;w.mark_changed();chat("RELEASE_NOW")
	if not await wait_for(func():return marker("RELEASE_CHECKED")):return
	check(not b.conditions.has("Grappled") and a.attacks_left==1,"Owner can release a hold for free outside its turn")
	w.data.combat.turn=0;a.action=false;a.attacks_left=0;w.mark_changed();chat("HELP_NOW")
	if not await wait_for(func():return marker("HELP_CHECKED")):return
	check(w.encounter.actions.help_attack(ally,b) and a.action,"Host applies remote Help to the selected enemy")
	w.data.combat.turn=2;w.command("attack",{"id":ally.id,"target":b.id});chat("HELP_CONSUMED")
	if not await wait_for(func():return marker("FINISHED")):return
	check(not w.encounter.actions.help_attack(ally,b),"Actual allied attack consumes remote Help")
	check(w.valid_campaign(w.data),"Network changes remain valid campaign data")
	print("ACTIONS_NETWORK_HOST "+str(passed)+" passed, "+str(failed)+" failed")
func client():
	check(w.join_session("127.0.0.1","actions-net",24727,"Creator player")==OK,"Player connects to character/action lobby")
	if not await wait_for(func():return w.client and w.network_label.begins_with("Connected") and w.can_control(w.actor("hero"))):return
	check(w.PROTOCOL==10 and not w.actor("ally").has("background") and w.actor("hidden").is_empty(),"New protocol preserves hidden creatures and private character details")
	check(w.actor("ally").conditions.has("Grappled") and w.actor("ally").effects[0].source=="","Actual network snapshot shows a hold without exposing the hidden grappler's identity")
	var graphical=OS.get_cmdline_user_args().has("--ui")
	if graphical:
		app=load("res://main.tscn").instantiate();root.add_child(app);await create_timer(.6).timeout;app.close_modal();app.seen_lobby=true;app.show_creator();await process_frame
		app.creator.fields.name.text="Network recruit";app.creator.fields.name.text_changed.emit("Network recruit");app.creator.draft.appearance.style="Mage";app.creator.reviewed.button_pressed=true;app.creator.submit.pressed.emit()
	else:
		var unit=w.read_json("res://assets/loadouts.json",{}).Wizard.duplicate(true);unit.name="Network recruit";unit.appearance=A.DEFAULTS.duplicate(true);unit.appearance.style="Mage";w.command("submit_hero",{"actor":unit})
	if not await wait_for(func():return w.data.actors.any(func(a):return a.name=="Network recruit") and w.data.combat.active):return
	var recruit=w.data.actors.filter(func(a):return a.name=="Network recruit")[0]
	check(w.can_control(recruit) and recruit.appearance.style=="Mage","Player receives its accepted customized character")
	var appearance=A.DEFAULTS.duplicate(true);appearance.style="Mage"
	w.command("customize_mini",{"id":"hero","appearance":appearance,"color":"#abc123","hp":9999,"owner":1})
	w.command("customize_mini",{"id":"ally","appearance":appearance,"color":"#abc123"});w.command("customize_mini",{"id":"foe","appearance":appearance,"color":"#abc123"})
	if not await wait_for(func():return w.actor("hero").appearance.style=="Mage"):return
	appearance.style="res://malicious.gd";w.command("customize_mini",{"id":"hero","appearance":appearance,"color":"#abc123"});await create_timer(.15).timeout
	check(w.actor("hero").hp==100 and w.actor("hero").appearance.style=="Mage","Invalid model paths and extra stat fields cannot alter the player's hero")
	chat("COSMETICS_CHECKED")
	if graphical:
		app.close_modal();app.battle_ui.actor_id="hero";w.selected="hero";app.battle_ui.choose_action("Grapple");app.battle_ui.pick_target("foe")
	else:w.command("combat_action",{"id":"hero","target":"foe","action":"Grapple","total":99999})
	if not await wait_for(func():return w.actor("foe").conditions.has("Grappled")):return
	check(w.actor("hero").attacks_left==1 and w.actor("foe").hp==1000,"Player sees the host's contested grapple result")
	chat("GRAPPLE_CHECKED")
	if not await wait_for(func():return marker("RELEASE_NOW")):return
	w.command("combat_action",{"id":"hero","target":"foe","action":"Release grapple"})
	if not await wait_for(func():return not w.actor("foe").conditions.has("Grappled")):return
	chat("RELEASE_CHECKED")
	if not await wait_for(func():return marker("HELP_NOW")):return
	w.command("combat_action",{"id":"hero","target":"foe","action":"Help attack"})
	if not await wait_for(func():return w.actor("foe").effects.any(func(e):return e.kind=="help_attack")):return
	chat("HELP_CHECKED")
	if not await wait_for(func():return marker("HELP_CONSUMED")):return
	check(not w.actor("foe").effects.any(func(e):return e.kind=="help_attack"),"Player receives consumption of the Help benefit")
	if graphical:check(app.board.actors.has(recruit.id),"Accepted player-created miniature is rendered in the real tactical view")
	chat("FINISHED");print("ACTIONS_NETWORK_CLIENT "+str(passed)+" passed, "+str(failed)+" failed")
