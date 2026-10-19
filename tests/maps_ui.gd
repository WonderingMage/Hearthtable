extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func frames():await process_frame;await process_frame;await process_frame
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1920,1080);await create_timer(.4).timeout;app.close_modal()
	for name in ["sanctum_crown","ember_rift"]:
		w.command("import_scene",{"package":w.read_json("res://assets/scenes/"+name+".json",{})});var s=w.data.scenes[-1];w.command("scene",{"scene":s.id});await frames();app.board.fit_map();await create_timer(.7).timeout
		check(w.data.scene==s.id and app.board.terrain.get_child_count()>0,name+" renders its authored map geometry")
		check(w.data.actors.filter(func(a):return a.hero).all(func(a):return app.board.actors.has(a.id) and app.board.actors[a.id].position.distance_to(Vector3(a.x+.5,app.board.floor_y(a)+.055,a.y+.5))<.15),name+" scene transfer places miniatures immediately at their new spawn")
		check(app.board.floor_texture!=null and app.board.floor_texture.get_width()==(1080 if name=="sanctum_crown" else 570),name+" retains the original image texture")
		app.battle_ui.toggle_enemy();await frames();check(app.battle_ui.tactical_hud.bottom.find_children("*","Button",true,false).any(func(button):return button.text=="Close enemy HUD"),name+" can exit enemy mode even when the map has no monsters");app.battle_ui.toggle_enemy();await frames()
		var editor=app.build_editor;editor.toggle();editor.category="Imported · Crown hall" if name=="sanctum_crown" else "Imported · Ember Rift";editor.refresh();await frames();app.board.fit_map();await create_timer(.6).timeout
		check(editor.catalog_list.get_child_count()==(7 if name=="sanctum_crown" else 5),name+" asset pack appears in the build catalog")
		check(app.board.camera_mode=="Isometric",name+" keeps the DM rotatable isometric view")
		root.get_texture().get_image().save_png("user://"+name+"_dm.png")
		editor.toggle();await frames()
		if name=="sanctum_crown":
			var hero=w.data.actors.filter(func(a):return a.hero)[0];w.data.actors=[hero];hero.x=15;hero.y=42;w.selected=hero.id;w.mark_changed();app.board.camera_mode="Tactical";app.battle_ui.actor_id=hero.id;app.battle_ui.selected_kind="move";app.board.targeting=false
			app.battle_ui.pick_ground(Vector2i(15,43));check(w.scene().doors_open.get("15,43",false),"Clicking a closed doorway opens it")
			app.battle_ui.pick_ground(Vector2i(15,43));check(hero.y==43 and w.scene().doors_open["15,43"],"Clicking an open doorway moves onto it without closing it")
			app.battle_ui.pick_ground(Vector2i(15,44));check(hero.y==44,"Clicking beyond the doorway finishes traversal")
			app.battle_ui.interact_door();check(not w.scene().doors_open["15,43"],"Separate Door control closes an empty doorway")
			app.board.set_view("Isometric")
	app.show_prepared_maps();await frames();check(app.modal_overlay!=null,"Prepared maps menu is available in the scene library");app.close_modal()
	root.size=Vector2i(1200,760);await frames();check(app.board.size.x<=root.size.x,"Map controls fit the minimum window")
	check(w.valid_campaign(w.data),"Rendered imported scenes remain valid campaign data")
	print("MAPS_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+ProjectSettings.globalize_path("user://"));quit(1 if failed else 0)
