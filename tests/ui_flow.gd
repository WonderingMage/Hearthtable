extends SceneTree
var app
func _initialize():call_deferred("run")
func snap(name: String):
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("user://"+name+".png")
	print("UI_CHECK "+name)
func run():
	await process_frame
	var world=root.get_node("World")
	world.reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await create_timer(0.5).timeout
	app.close_modal();await snap("table")
	app.show_welcome();await snap("welcome");app.close_modal()
	app.show_learn();await snap("learn");app.close_modal()
	app.show_creator();await snap("creator");app.close_modal()
	app.edit_actor(world.actor("hero1"));await snap("edit");app.close_modal()
	app.show_map_settings();await snap("map_settings");app.close_modal()
	app.show_session();await snap("session");app.close_modal()
	app.side_tab="Combat";world.command("initiative");app.refresh_side();await snap("combat")
	app.side_tab="Journal";app.refresh_side();await snap("journal")
	app.side_tab="Library";app.refresh_side();await snap("library")
	var spell=world.spells.filter(func(s):return s.index=="magic-missile")[0]
	app.show_compendium_entry(spell);await snap("spell");app.close_modal()
	var monster=world.monsters.filter(func(m):return m.index=="goblin")[0]
	app.show_compendium_entry(monster);await snap("monster");app.close_modal()
	for m in world.monsters:
		var a=app.monster_actor(m)
		if not load("res://scripts/rules.gd").roll(a.damage).ok:push_error("Invalid monster attack "+str(m.name)+" "+a.damage)
	app.side_tab="Character";app.refresh_side();world.preview=true;app.refresh();await snap("player_preview")
	print("UI_FLOW_COMPLETE "+ProjectSettings.globalize_path("user://"))
	quit()
