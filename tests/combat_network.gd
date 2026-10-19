extends SceneTree
var w
var rejection=""
func _initialize():call_deferred("run")
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	if OS.get_cmdline_user_args().has("--host"):
		w.command("new_campaign",{"title":"Range network test","heroes":false})
		var loadouts=w.read_json("res://assets/loadouts.json",{})
		var a=loadouts.Fighter.duplicate(true);var b=a.duplicate(true)
		a.id="hero1";a.name="Attacker";a.scene=w.data.scene;a.x=2;a.y=5
		b.id="foe";b.name="Target";b.hero=false;b.scene=w.data.scene;b.x=6;b.y=5;b.token_size=2;b.hp=1000;b.max_hp=1000
		w.data.actors=[a,b];w.mark_changed()
		if w.host_session("range-test")!=OK:quit(1);return
		await create_timer(6).timeout
		var attacks=w.data.log.filter(func(line):return line.text.begins_with("⚔"))
		var ok=w.peers.size()==1 and w.actor("hero1").x==5 and w.actor("hero1").action and attacks.size()==1 and attacks[0].text.contains("5 ft")
		print("RANGE_NETWORK_HOST "+("PASS" if ok else "FAIL"));quit(0 if ok else 1)
	else:
		w.message.connect(func(text):rejection=text)
		if w.join_session("127.0.0.1","range-test")!=OK:quit(1);return
		await create_timer(1).timeout
		var ok=w.client and w.network_label.begins_with("Connected")
		w.command("attack",{"id":"hero1","target":"foe","range":10000,"ignore_range":true})
		await create_timer(0.5).timeout
		ok=ok and rejection.contains("Out of range") and not w.actor("hero1").action and not w.data.log.any(func(line):return line.text.begins_with("⚔"))
		w.command("move",{"id":"hero1","x":5,"y":5});await create_timer(0.5).timeout
		w.command("attack",{"id":"hero1","target":"foe"});await create_timer(0.5).timeout
		ok=ok and w.actor("hero1").action and w.data.log.any(func(line):return line.text.begins_with("⚔") and line.text.contains("5 ft"))
		w.command("attack",{"id":"hero1","target":"foe","attack_index":99});await create_timer(0.5).timeout
		ok=ok and rejection.contains("valid attack")
		print("RANGE_NETWORK_CLIENT "+("PASS" if ok else "FAIL"))
		await create_timer(4).timeout;quit(0 if ok else 1)
