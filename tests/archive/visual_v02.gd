extends SceneTree
var app
func _initialize():call_deferred("run")
func snapshot(name: String):
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("user://"+name+".png");print("SNAP "+name)
func run():
	await process_frame
	root.get_node("World").reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await create_timer(1.5).timeout
	app.close_modal()
	await snapshot("diorama")
	app.board.focus_selected();await create_timer(0.3).timeout
	await snapshot("miniatures")
	app.board.set_view("Isometric");await snapshot("isometric")
	app.board.set_view("Top down");await snapshot("top_down")
	app.show_display_settings();await snapshot("display")
	app.close_modal();app.show_map_settings();await snapshot("grid")
	app.close_modal();app.board.set_view("Diorama")
	print("VISUAL_DONE "+ProjectSettings.globalize_path("user://"));quit()
