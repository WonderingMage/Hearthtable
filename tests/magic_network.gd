extends SceneTree
var w
var last_error=""
var passed=0
var failed=0
var app
func frames():
	await process_frame
	await process_frame
	await process_frame
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func wait_for(condition: Callable,seconds: float=10.0):
	seconds=maxf(seconds,30.0)
	var started=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started<int(seconds*1000):await create_timer(0.05).timeout
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.message.connect(func(text):last_error=text)
	if OS.get_cmdline_user_args().has("--host"):
		w.command("new_campaign",{"heroes":false});w.encounter.ensure_data();w.data.automation.auto_initiative=false;var loadouts=w.read_json("res://assets/loadouts.json",{})
		var a=loadouts.Wizard.duplicate(true);a.id="hero1";a.scene=w.data.scene;a.x=2;a.y=3
		var b=loadouts.Fighter.duplicate(true);b.id="target";b.hero=false;b.scene=w.data.scene;b.x=4;b.y=3;b.hp=500;b.max_hp=500
		w.data.actors=[a,b];w.mark_changed()
		check(w.host_session("magic-net",24705,true)==OK,"DM hosts on chosen UDP port")
		await wait_for(func():return w.session.players.size()==1)
		check(w.peers.size()==1 and w.session.phase=="lobby","New guest joins host lobby")
		await wait_for(func():return not w.session.requests.is_empty())
		check(w.session.requests.size()==1,"Player submits a character for host review")
		if not w.session.requests.is_empty():
			var peer=int(w.session.requests.keys()[0]);w.command("review_hero",{"peer":peer,"accept":true})
			check(w.data.actors.any(func(unit):return unit.name=="Submitted Hero" and int(unit.owner)==peer),"DM acceptance adds player-owned character")
		await wait_for(func():return w.session.players.values().any(func(p):return p.ready))
		check(w.session.players.values().any(func(p):return p.ready),"Ready status reaches the DM")
		w.command("lobby_start")
		w.command("build_edit",{"op":"place","asset":"bookcase","x":8,"y":5})
		await wait_for(func():return a.slots[0]==1)
		check(a.slots[0]==1 and b.hp<500,"Host resolves player casting and spends exactly one slot")
		if OS.get_cmdline_user_args().has("--tactical"):check(a.x==3,"Host validates the tactical client’s click-to-move command")
		check(w.data.title=="Our campaign","Players cannot rename the host campaign")
		await wait_for(func():return w.data.log.any(func(line):return line.text.contains("CLIENT_DONE")))
		w.command("new_scene",{"title":"Secret future scene"});var future=w.data.scenes[-1]
		var image=Image.create(8,8,false,Image.FORMAT_RGB8);image.fill(Color.RED);future.image=Marshalls.raw_to_base64(image.save_png_to_buffer())
		w.command("scene",{"scene":future.id});await create_timer(0.3).timeout
		w.command("scene",{"scene":"start"});await create_timer(0.3).timeout
		w.command("scene",{"scene":future.id});await wait_for(func():return w.data.log.any(func(line):return line.text.contains("CACHE_CONFIRMED")))
		check(w.peers.size()==1,"Client remains connected across scene transfers")
		print("MAGIC_NETWORK_HOST "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
	else:
		check(w.join_session("127.0.0.1","magic-net",24705,"Alice")==OK,"Player joins a custom UDP port")
		await wait_for(func():return w.network_label.begins_with("Connected"))
		check(w.client and w.session.phase=="lobby" and w.session.players.values().any(func(p):return p.name=="Alice"),"Guest receives player lobby and their name")
		check(w.can_control(w.actor("hero1")) and not w.can_control(w.actor("target")),"Guest controls assigned hero only")
		if OS.get_cmdline_user_args().has("--ui"):
			app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(2560,1440);await create_timer(0.5).timeout;app.show_session();await frames()
			check(app.modal_tag=="session" and app.preview_button.disabled,"Joined UI opens player lobby with locked player view")
			root.get_texture().get_image().save_png("user://player_lobby.png")
		w.command("move",{"id":"hero1","x":9,"y":3});await create_timer(0.2).timeout
		check(w.actor("hero1").x==2 and last_error.contains("not started"),"Lobby blocks premature table actions")
		var unit=w.read_json("res://assets/loadouts.json",{}).Fighter.duplicate(true);unit.id="submitted";unit.name="Submitted Hero";unit.scene=w.data.scene
		w.command("submit_hero",{"actor":unit});w.command("lobby_ready",{"ready":true})
		await wait_for(func():return w.session.phase=="table")
		check(w.data.actors.any(func(a):return a.name=="Submitted Hero" and w.can_control(a)),"Accepted character is controllable by submitter")
		w.command("campaign_name",{"title":"Unauthorized"})
		var cast={"id":"hero1","spell":"magicmissile","slot":1,"targets":["target","target","target"],"components":true,"area_confirmed":true}
		if app!=null and OS.get_cmdline_user_args().has("--tactical"):
			app.close_modal();w.selected="hero1";app.battle_ui.actor_id="hero1";await frames()
			check(app.board.camera_mode=="Tactical" and app.battle_ui.tactical_hud.visible,"Joined player receives the tactical camera and HUD")
			app.battle_ui.pick_ground(Vector2i(3,3));await wait_for(func():return w.actor("hero1").x==3)
			check(w.actor("hero1").x==3,"Tactical ground click receives the host-validated destination")
			app.battle_ui.choose_spell("magicmissile");app.battle_ui.components=true;app.battle_ui.refresh();app.battle_ui.pick_target("target")
		else:w.command("cast_spell",cast)
		await wait_for(func():return w.actor("hero1").slots[0]==1)
		check(w.actor("hero1").slots[0]==1 and w.actor("target").hp<500,"Player sees authoritative slot and damage results")
		if app!=null:
			app.close_modal();await frames();check(app.dm_controls.all(func(b):return b.disabled),"Player UI disables host-only creation/save controls")
			app.character_ui.show_book("hero1");await frames();root.get_texture().get_image().save_png("user://player_spellbook.png");app.close_modal()
		w.command("cast_spell",{"id":"target","spell":"magicmissile","slot":1,"components":true});await create_timer(0.2).timeout
		check(last_error.contains("assigned"),"Host rejects casting for someone else’s token")
		await wait_for(func():return not w.scene().get("props",[]).is_empty())
		check(w.scene().get("props",[]).size()==1,"Player receives host-authored scene furniture")
		var prop=w.scene().props[0];w.command("build_edit",{"op":"delete","uid":prop.uid});await create_timer(.2).timeout
		check(w.scene().props.size()==1 and last_error.contains("DM"),"Host refuses player edits to the build catalog objects")
		w.command("chat",{"text":"CLIENT_DONE"})
		await wait_for(func():return w.data.scene!="start")
		check(w.data.scenes.size()==1,"Player receives active scene only")
		await create_timer(0.7).timeout
		check(w.data.scene!="start" and not w.scene().image.is_empty() and w.scene().image!="__cached__","Returning to an earlier scene restores its cached image")
		w.command("chat",{"text":"CACHE_CONFIRMED"})
		print("MAGIC_NETWORK_CLIENT "+str(passed)+" passed, "+str(failed)+" failed");await create_timer(2).timeout;quit(1 if failed else 0)
