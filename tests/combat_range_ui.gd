extends SceneTree
var app
var w
var passed=0
var failed=0
func check(value: bool,description: String):
	if value:passed+=1;print("PASS "+description)
	else:failed+=1;push_error("FAIL "+description)
func _initialize():call_deferred("run")
func frames():
	await process_frame
	await process_frame
	await process_frame
func button_named(node: Node,value: String):
	if node is Button and node.text==value:return node
	for child in node.get_children():
		var found=button_named(child,value)
		if found:return found
	return null
func option_containing(node: Node,value: String):
	if node is OptionButton:
		for i in node.item_count:
			if node.get_item_text(i).contains(value):return node
	for child in node.get_children():
		var found=option_containing(child,value)
		if found:return found
	return null
func has_label(node: Node,value: String) -> bool:
	if node is Label and node.text.contains(value):return true
	for child in node.get_children():
		if has_label(child,value):return true
	return false
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await create_timer(0.5).timeout;app.close_modal();root.size=Vector2i(1920,1200);await frames()
	w.command("new_campaign",{"title":"Reach matters","heroes":false});w.command("resize",{"width":20,"height":14})
	w.encounter.ensure_data();w.data.automation.auto_initiative=false
	var a=app.monster_actor(w.monster_lookup.troll);a.id="troll";a.scene=w.data.scene;a.x=4;a.y=5
	var b=app.loadouts.Fighter.duplicate(true);b.id="hero";b.name="Training target";b.scene=w.data.scene;b.x=7;b.y=5
	w.data.actors=[a,b];w.selected=a.id;w.mark_changed();await frames();app.board.focus_selected();await frames()
	check(button_named(app.side,"Attack").disabled,"Attack button is disabled outside troll's 5-ft reach")
	check(has_label(app.side,"Out of range: 10 ft"),"Inspector explains measured distance and required reach")
	check(app.board.attack_preview.get("distance",-1)==10 and not app.board.attack_preview.get("ok",true),"Scene loading preserves the inspector's blocked attack preview")
	root.get_texture().get_image().save_png("user://RangeBlocked.png")
	w.command("move",{"id":b.id,"x":6,"y":5});await frames()
	check(not button_named(app.side,"Attack").disabled,"Moving target into reach enables Attack")
	check(has_label(app.side,"In range · 5 ft"),"Inspector updates after movement")
	check(app.board.attack_preview.get("ok",false),"Board displays valid target indicator")
	root.get_texture().get_image().save_png("user://RangeReady.png")
	var choice=option_containing(app.side,"Claw")
	check(choice!=null and choice.item_count==2,"Troll attack menu includes individual Bite and Claw profiles")
	choice.select(1);choice.item_selected.emit(1)
	check(app.chosen_attacks[a.id]==1 and app.board.attack_preview.get("profile",{}).get("name","")=="Claw","Choosing Claw updates actual attack profile")
	w.command("move",{"id":b.id,"x":6,"y":6});await frames()
	check(option_containing(app.side,"Claw").selected==1,"Chosen attack persists when positions update")
	app.roll_select.select(1);app.roll_select.item_selected.emit(1);await frames()
	check(app.board.attack_preview.get("mode",-1)==1 and has_label(app.side,"Chosen advantage"),"Roll-mode changes immediately update attack preview")
	app.side_tab="Combat";app.refresh_side();check(app.board.attack_preview.is_empty(),"Switching panels clears transient target indicator")
	app.side_tab="Character";w.selected=b.id;b.weapon="Longbow";a.x=14;w.mark_changed();await frames()
	check(app.board.attack_preview.get("profile",{}).get("kind","")=="ranged" and not button_named(app.side,"Attack").disabled,"Standard bow profile recognized on an existing sheet")
	app.edit_actor(b);await frames()
	var type_choice=option_containing(app.modal_overlay,"Melee");check(type_choice!=null and type_choice.selected==1,"Editor shows recognized ranged profile")
	var close_exception=button_named(app.modal_overlay,"Feature ignores ranged disadvantage from adjacent foes");close_exception.button_pressed=true
	button_named(app.modal_overlay,"Save sheet").pressed.emit();await frames()
	check(b.attack_type=="ranged" and b.range_normal_ft==150 and b.range_long_ft==600 and b.ignore_close_range,"Saving editor persists range and approved feature exception")
	check(w.valid_campaign(w.data),"Campaign with attack profiles and range settings validates")
	var audited=0;var valid=true
	for monster in w.monsters:
		var unit=app.monster_actor(monster);unit.id="audit";unit.scene=w.data.scene
		for profile in w.attack_profiles(unit):
			if unit.weapon!="No basic attack":valid=valid and profile.known and C_valid_damage(profile.damage);audited+=1
	check(valid and audited>500,"Every imported SRD attack has a known range and valid basic damage")
	print("COMBAT_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
func C_valid_damage(value: String) -> bool:return load("res://scripts/combat_rules.gd").valid_damage(value)
