extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func wait_for(test: Callable) -> bool:
	for i in 600:
		if test.call():return true
		await create_timer(.05).timeout
	check(false,"Timed out waiting for scene synchronization");return false
func marker(word: String) -> bool:return w.data.log.any(func(e):return e.text.contains(word))
func say(word: String):w.command("chat",{"text":word})
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	if OS.get_cmdline_user_args().has("--host"):
		w.command("import_scene",{"package":w.read_json("res://assets/scenes/sanctum_crown.json",{})});var crown=w.data.scenes[-1].id
		w.command("import_scene",{"package":w.read_json("res://assets/scenes/ember_rift.json",{})});var ember=w.data.scenes[-1].id
		w.command("scene",{"scene":crown});var a=w.data.actors.filter(func(unit):return unit.hero)[0];w.data.actors=[a];a.x=15;a.y=41;a.owner=1;w.encounter.ensure_data();w.data.automation.auto_initiative=false;w.mark_changed()
		check(w.host_session("map-downloads",24720)==OK,"Host serves custom scene content on the selected UDP port")
		await wait_for(func():return marker("COLD_READY"));check(w.peers.size()==1,"Player joins after downloading the custom scene")
		check(a.y==44 and not w.scene().doors_open.get("15,43",false),"Host validates the player's approach, opening, traversal and closing of a double gate")
		check(w.scene_sync.blobs.size()>=2,"Host prepares separate content-addressed map and asset blobs")
		w.command("scene",{"scene":ember});await wait_for(func():return marker("EMBER_READY"));check(a.scene==ember,"Scene changes trigger a new authoritative map transfer")
		w.command("scene",{"scene":crown});await wait_for(func():return marker("CACHE_READY"))
		check(w.scene_sync.approved.values().all(func(hashes):return hashes.size()==2),"Host authorizes only the active scene's required blobs")
		await wait_for(func():return marker("REJOIN_READY"));check(w.peers.size()==1,"Cached reconnect completes without manual map installation")
		print("MAPS_NETWORK_HOST "+str(passed)+" passed, "+str(failed)+" failed");await create_timer(.5).timeout;quit(1 if failed else 0)
	else:
		check(not w.BUILD.catalog.has("pack_crown_throne"),"Fresh player starts without the host's custom asset pack mounted")
		if OS.get_cmdline_user_args().has("--ui"):
			app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000);await create_timer(.3).timeout;app.close_modal()
		check(w.join_session("127.0.0.1","map-downloads",24720,"Map explorer")==OK,"Player connects using the normal join flow")
		await wait_for(func():return w.scene_loading)
		check(w.scene_loading and w.scene_sync.progress<1,"Cold join reports downloading progress before entering the scene")
		if app!=null:
			await process_frame;await process_frame;root.get_texture().get_image().save_png("user://map_downloading.png")
		await wait_for(func():return not w.scene_loading and w.scene_sync.ready and w.scene().name=="Sanctum of the Crown")
		check(w.scene_sync.transferred>3000000,"Player automatically downloads the full-size custom map")
		check(w.BUILD.catalog.has("pack_crown_throne") and w.scene().asset_pack.size()==7,"Custom asset recipes download and mount automatically")
		var image=Image.new();check(image.load_png_from_buffer(Marshalls.base64_to_raw(w.scene().image))==OK and image.get_width()==1080,"Downloaded map texture validates and retains its original resolution")
		check(w.data.scenes.size()==1 and not w.scene().has("battle_zones") and w.scene().dm_notes.is_empty(),"Downloads exclude future scenes and private DM information")
		check(not w.BUILD.catalog.has("pack_ember_ridge"),"Future-scene asset definitions are not downloaded early")
		var a=w.data.actors.filter(func(unit):return w.can_control(unit))[0];w.selected=a.id
		if app!=null:
			await process_frame;app.close_modal();app.battle_ui.actor_id=a.id;app.battle_ui.cancel_selection();app.battle_ui.pick_ground(Vector2i(15,43))
		else:w.command("move",{"id":a.id,"x":15,"y":42});w.command("door",{"id":a.id,"x":15,"y":43,"open":true})
		await wait_for(func():return w.scene().doors_open.get("15,43",false))
		check(w.scene().doors_open.get("16,43",false),"Remote door interaction opens both linked leaves")
		if app!=null:app.battle_ui.pick_ground(Vector2i(15,43))
		else:w.command("move",{"id":a.id,"x":15,"y":43})
		await wait_for(func():return w.actor(a.id).y==43);check(w.scene().doors_open["15,43"],"Stepping onto an open door never closes it")
		w.command("door",{"id":a.id,"x":15,"y":43});await create_timer(.15).timeout;check(w.scene().doors_open["15,43"],"Host prevents closing the doorway on its occupant")
		if app!=null:app.battle_ui.pick_ground(Vector2i(15,44))
		else:w.command("move",{"id":a.id,"x":15,"y":44})
		await wait_for(func():return w.actor(a.id).y==44);w.command("door",{"id":a.id,"x":15,"y":43});await wait_for(func():return not w.scene().doors_open["15,43"])
		check(w.actor(a.id).y==44,"Player finishes a real network traversal through the gate")
		if app!=null:
			app.board.focus_selected();await create_timer(.3).timeout;root.get_texture().get_image().save_png("user://crown_player.png")
		say("COLD_READY");await wait_for(func():return not w.scene_loading and w.scene_sync.ready and w.scene().name.begins_with("Ember Rift"))
		check(w.BUILD.catalog.has("pack_ember_ridge") and w.scene().asset_pack.size()==5,"Scene switching automatically downloads the volcanic asset pack")
		check(w.scene().lighting.time=="Night" and not w.scene().image.is_empty(),"Scene switch applies the map texture and night lighting together")
		if app!=null:
			app.board.focus_selected();await create_timer(.3).timeout;root.get_texture().get_image().save_png("user://ember_player.png")
		var bytes=w.scene_sync.transferred;say("EMBER_READY");await wait_for(func():return not w.scene_loading and w.scene().name=="Sanctum of the Crown")
		check(w.scene_sync.transferred==bytes,"Returning to a cached scene transfers no map or asset bytes")
		check(w.BUILD.catalog.has("pack_crown_throne"),"Cached custom assets remount with the returning scene")
		say("CACHE_READY");await create_timer(.25).timeout;w.disconnect_session();w.scene_sync.blobs.clear();await create_timer(.35).timeout
		check(w.join_session("127.0.0.1","map-downloads",24720,"Map explorer")==OK,"Player rejoins without preinstalling the custom map")
		await wait_for(func():return w.scene_sync.ready and not w.scene_loading and w.scene().name=="Sanctum of the Crown" and w.network_label.begins_with("Connected"))
		check(w.scene_sync.transferred==bytes and w.scene_sync.cache_hits>=2,"Rejoining reuses the verified on-disk map and asset cache")
		check(w.scene_sync.valid_hash(w.scene().asset_manifest[0].hash),"Downloaded cache remains tied to the content hash")
		say("REJOIN_READY");print("MAPS_NETWORK_CLIENT "+str(passed)+" passed, "+str(failed)+" failed");await create_timer(1).timeout;quit(1 if failed else 0)
