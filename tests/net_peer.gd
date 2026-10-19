extends SceneTree
var w
func _initialize():call_deferred("run")
func run():
	await process_frame
	w=root.get_node("World")
	w.data=w.read_json("res://assets/starter.json",{})
	w.data.journal_dm="SECRET_DM_NOTE_DO_NOT_TRANSMIT"
	if OS.get_cmdline_user_args().has("--host"):
		var error=w.host_session("lan-test")
		if error!=OK:push_error("HOST FAILED");quit(1);return
		await create_timer(6).timeout
		var ok=w.peers.size()==1 and w.actor("hero1").x==7 and w.actor("hero2").x==6 and w.data.title=="The Lantern Below"
		ok=ok and w.data.log.any(func(e):return e.text.contains("network hello"))
		print("NETWORK_HOST "+("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	else:
		var original=w.data.duplicate(true)
		var error=w.join_session("127.0.0.1","lan-test")
		if error!=OK:push_error("JOIN FAILED");quit(1);return
		await create_timer(2).timeout
		var ok=w.client and w.network_label.begins_with("Connected")
		ok=ok and w.data.journal_dm=="" and not JSON.stringify(w.data).contains("SECRET_DM_NOTE_DO_NOT_TRANSMIT")
		ok=ok and not w.data.actors.any(func(a):return a.id=="foe2")
		ok=ok and w.can_control(w.actor("hero1")) and not w.can_control(w.actor("hero2"))
		w.command("move",{"id":"hero1","x":7,"y":7})
		w.command("move",{"id":"hero2","x":20,"y":7})
		w.command("campaign_name",{"title":"Unauthorized"})
		w.command("chat",{"text":"network hello"})
		await create_timer(1).timeout
		ok=ok and w.actor("hero1").x==7 and w.actor("hero2").x==6 and w.data.title=="The Lantern Below"
		print("NETWORK_CLIENT "+("PASS" if ok else "FAIL"))
		# Remain until host verifies, then verify local campaign restoration.
		await create_timer(4).timeout
		ok=ok and not w.client and w.data.journal_dm==original.journal_dm and w.actor("hero1").x==5
		print("NETWORK_DISCONNECT_RESTORE "+("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
