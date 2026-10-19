extends SceneTree
var w
func _initialize():call_deferred("run")
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	if OS.get_cmdline_user_args().has("--host"):
		w.command("new_campaign",{"title":"Network rooms","heroes":true});w.command("resize",{"width":13,"height":9})
		for a in w.data.actors:a.x=3;a.y=4
		w.actor("hero1").x=5
		for x in range(1,12):w.command("tile",{"x":x,"y":1,"tile":3});w.command("tile",{"x":x,"y":7,"tile":3})
		for y in range(2,7):
			for x in [1,6,11]:w.command("tile",{"x":x,"y":y,"tile":3})
		w.command("tile",{"x":6,"y":4,"tile":6})
		var foe=w.read_json("res://assets/starter.json",{}).actors[4].duplicate(true);foe.id="room_enemy";foe.scene=w.data.scene;foe.x=8;foe.y=4;w.data.actors.append(foe)
		w.mark_changed()
		if w.host_session("room-test")!=OK:quit(1);return
		await create_timer(7).timeout
		var ok=w.peers.size()==1 and w.actor("hero1").x==5 and not w.scene().doors_open.get("6,4",false)
		ok=ok and w.data.log.any(func(e):return e.text.contains("Door G5 opened")) and w.data.log.any(func(e):return e.text.contains("Door G5 closed"))
		print("ROOM_NETWORK_HOST "+("PASS" if ok else "FAIL"));quit(0 if ok else 1)
	else:
		if w.join_session("127.0.0.1","room-test")!=OK:quit(1);return
		await create_timer(1.2).timeout
		var ok=w.client and w.network_label.begins_with("Connected") and w.can_control(w.actor("hero1"))
		ok=ok and not w.cell_visible(Vector2i(8,4)) and w.actor("room_enemy").is_empty()
		w.command("door",{"id":"hero1","x":6,"y":4});await create_timer(0.5).timeout
		ok=ok and w.cell_visible(Vector2i(8,4)) and not w.actor("room_enemy").is_empty() and w.scene().doors_open.get("6,4",false)
		w.command("move",{"id":"hero1","x":7,"y":4});await create_timer(0.5).timeout
		ok=ok and w.actor("hero1").x==7
		w.command("move",{"id":"hero1","x":5,"y":4});await create_timer(0.5).timeout
		w.command("door",{"id":"hero1","x":6,"y":4});await create_timer(0.5).timeout
		ok=ok and not w.cell_visible(Vector2i(8,4)) and w.actor("room_enemy").is_empty() and not w.scene().doors_open.get("6,4",false)
		w.command("move",{"id":"hero1","x":7,"y":4});await create_timer(0.5).timeout
		ok=ok and w.actor("hero1").x==5
		print("ROOM_NETWORK_CLIENT "+("PASS" if ok else "FAIL"))
		await create_timer(4).timeout;quit(0 if ok else 1)
