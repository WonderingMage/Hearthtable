extends SceneTree
var app
var w
var passed=0
var failed=0
func check(value: bool,message: String):
	if value:passed+=1;print("PASS "+message)
	else:failed+=1;push_error("FAIL "+message)
func _initialize():call_deferred("run")
func frames():
	await process_frame
	await process_frame
func click_at(pos: Vector2,pressed: bool):
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=pos;app.board._gui_input(e)
func run():
	await process_frame
	w=root.get_node("World");w.reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await create_timer(1.0).timeout;app.close_modal();await frames()
	var b=app.board
	check(b.actors.size()==7,"All starter miniatures instantiated")
	check(b.terrain.get_child_count()>10,"3D terrain exists")
	check(b.viewport.size.x==int(round(b.size.x)),"Native viewport width, no downscaling")
	var r=load("res://scripts/rules.gd")
	check(r.grid_distance(Vector2i(0,0),Vector2i(3,3),5,"5e")==15,"2014 diagonal metric")
	check(r.grid_distance(Vector2i(0,0),Vector2i(3,3),5,"5105")==20,"Alternate 5-10-5 metric")
	check(is_equal_approx(r.grid_distance(Vector2i(0,0),Vector2i(3,4),5,"euclidean"),25),"Euclidean metric")
	check(r.column_name(0)=="A" and r.column_name(25)=="Z" and r.column_name(26)=="AA" and r.column_name(59)=="BH","Grid coordinate references")
	var a=w.actor("hero1")
	var point=Vector3(a.x+0.5,0,a.y+0.5)
	check(b.cell_at(b.project(point))==Vector2i(a.x,a.y),"Orthographic screen/world picking round-trip")
	var old=Vector2i(a.x,a.y)
	click_at(b.project(point+Vector3.UP*0.45),true)
	check(b.drag_id==a.id,"Clicking figure selects it for drag")
	b.drag_cell=old+Vector2i(1,0)
	click_at(b.project(Vector3(old.x+1.5,0,old.y+0.5)),false)
	check(int(a.x)==old.x+1,"Dragging commits snapped movement")
	w.undo();a=w.actor("hero1")
	w.command("grid_settings",{"distance":10.0,"unit":"ft","metric":"5e","pixels":100,"offset_x":12,"offset_y":24})
	check(w.measure_cells(Vector2i(0,0),Vector2i(2,1))==20,"Scene ruler obeys configured square size")
	check(w.scene().grid_pixels==100 and w.scene().grid_offset_x==12,"Source image grid calibration persists")
	w.command("grid_settings",{"distance":1.5,"unit":"m","metric":"5e"})
	check(is_equal_approx(w.movement_feet(Vector2i(0,0),Vector2i(1,0)),4.9212598425),"Metric scale converts movement to canonical feet")
	w.command("grid_settings",{"distance":5,"unit":"ft","metric":"5e"})
	w.preview=true;w.mark_changed();await frames();await frames()
	check(b.actors.size()==6,"Player view excludes fogged miniature")
	w.preview=false;w.mark_changed();await frames()
	# A real native-sized viewport is retained when UI scale increases.
	root.content_scale_factor=1.25;app.ui_scale=1.25;await frames();b.resize_view();await frames()
	check(absi(b.viewport.size.x-int(round(b.size.x*1.25)))<=1,"125% UI retains physical-pixel 3D width")
	root.get_texture().get_image().save_png("user://dpi125.png")
	root.content_scale_factor=1.0;app.ui_scale=1.0;await frames();b.resize_view();await frames()
	# Test a calibrated imported image and its shader.
	var image=Image.create(1024,1024,false,Image.FORMAT_RGBA8);image.fill(Color("6d7e91"))
	var file="user://image_fixture.png";image.save_png(file);app.import_image(ProjectSettings.globalize_path(file));await frames()
	check(not str(w.scene().image).is_empty(),"Image import embeds the map")
	w.command("grid_settings",{"distance":5,"unit":"ft","metric":"5e","pixels":64,"offset_x":0,"offset_y":0});await frames();await frames()
	check(b.floor_texture!=null,"Calibrated map texture built")
	w.reset_starter();await frames();await frames()
	# Resize and inspect the native 2.5D scene at 1440p.
	root.size=Vector2i(2560,1440);await create_timer(0.5).timeout;await frames();b.resize_view();await frames();print("SIZES "+str(root.size)+" / "+str(root.get_texture().get_size())+" / "+str(DisplayServer.window_get_size()))
	check(Vector2i(root.get_texture().get_size())==Vector2i(2560,1440),"Native 1440p output")
	root.get_texture().get_image().save_png("user://native1440p.png")
	print("INTERACTION_RESULT "+str(passed)+" passed, "+str(failed)+" failed")
	quit(1 if failed else 0)
