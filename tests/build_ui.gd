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
	await process_frame;w=root.get_node("World");w.reset_starter();app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000);await create_timer(.5).timeout;app.close_modal();await frames()
	check(app.board.camera_mode=="Isometric","DM starts in the sole isometric view")
	for name in ["Tactical","First person","Following","Top down","Diorama"]:
		app.board.set_view(name);check(app.board.camera_mode=="Isometric","DM cannot switch to "+name)
	check(not app.camera_options.visible,"Unused camera-mode selector is removed from the interface")
	var editor=app.build_editor;editor.toggle();await frames();check(editor.active and editor.root.get_parent().visible,"F2 build catalog opens as a modeless workspace")
	check(app.immersion_panels.all(func(p):return not p.visible),"Building gives the board space by hiding play sidebars")
	check(editor.catalog_list.get_child_count()==16,"Terrain category shows illustrated floor materials")
	editor.category="Furnishings";editor.populate();await frames();check(editor.catalog_list.get_child_count()==11,"Furnishing catalog contains separate throne and furniture designs")
	editor.choose("throne");editor.hover=Vector2i(6,6);editor.update_ghost();await frames();check(is_instance_valid(editor.ghost),"Object selection shows a full 3D placement ghost")
	check(editor.ghost.get_child_count()>10,"Throne preview has modeled upholstery, arms, legs and crown detail")
	editor.rotation=1;editor.update_ghost();await frames();check(absf(editor.ghost.rotation.y-PI/2)<.01,"R rotation turns the placement preview by a quarter-turn")
	w.command("new_campaign",{"heroes":false});app.board.fit_map();await frames();editor.choose("bench");editor.rotation=1;await frames()
	var point=app.board.project(Vector3(5.5,0,5.5));var press=InputEventMouseButton.new();press.position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;editor.handle(press);await frames()
	check(w.scene().props.size()==1 and w.scene().props[0].rotation==1,"Map-click placement commits the catalog object and rotation")
	var uid=w.scene().props[0].uid;editor.mode="Move";editor.handle(press);await frames();press.position=app.board.project(Vector3(8.5,0,8.5));editor.handle(press);await frames()
	check(w.scene().props[0].uid==uid and w.scene().props[0].x==8,"Pickup and map-click move preserve the placed object identity")
	var cancel=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true;editor.handle(cancel);await frames();check(editor.mode=="Select" and not is_instance_valid(editor.ghost),"Right-click fully cancels placement until another tool is chosen")
	w.command("new_campaign",{"heroes":true});await frames()
	for theme in ["Throne hall","Volcanic crossing","Tidal ruins","Woodland camp","Frozen pass"]:
		w.command("build_edit",{"op":"template","theme":theme});editor.cancel();app.board.fit_map();await frames();check(w.scene().name==theme and app.board.terrain.get_child_count()>0,theme+" renders as editable 3D scenery")
		if theme in ["Throne hall","Volcanic crossing","Tidal ruins"]:
			root.get_texture().get_image().save_png("user://build_"+theme.to_lower().replace(" ","_")+".png")
	root.size=Vector2i(1200,760);await frames();check(editor.root.get_parent().size.x<=root.size.x,"Build catalog fits the minimum window width")
	check(app.board.size.y>=330,"Building preserves a usable map viewport at minimum height")
	root.get_texture().get_image().save_png("user://build_minimum.png")
	editor.toggle();await frames();check(app.immersion_panels.all(func(p):return p.visible),"Exiting build restores DM creature and encounter tools")
	w.client=true;await frames();check(app.board.camera_mode=="Tactical","Players use only the tactical view")
	for name in ["Isometric","First person","Following","Top down"]:app.board.set_view(name);check(app.board.camera_mode=="Tactical","Player cannot switch to "+name)
	editor.toggle();check(not editor.active,"Players cannot open the DM build editor")
	w.client=false;await frames();app.close_modal();check(w.valid_campaign(w.data),"Rendered build scenes remain valid campaign data")
	print("BUILD_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+ProjectSettings.globalize_path("user://"));quit(1 if failed else 0)
