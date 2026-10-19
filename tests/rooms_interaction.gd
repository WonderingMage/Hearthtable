extends SceneTree
var app
var w
var b
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
func button(pos: Vector2,pressed: bool,shift: bool=false,index: int=MOUSE_BUTTON_LEFT):
	var e=InputEventMouseButton.new();e.position=pos;e.pressed=pressed;e.shift_pressed=shift;e.button_index=index;b._gui_input(e)
func has_option(node: Node,value: String) -> bool:
	if node is OptionButton:
		for i in node.item_count:
			if node.get_item_text(i)==value:return true
	for child in node.get_children():
		if has_option(child,value):return true
	return false
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await create_timer(0.5).timeout;app.close_modal()
	root.size=Vector2i(1920,1200);await frames();b=app.board
	w.command("new_campaign",{"title":"The Door Between","heroes":true});w.command("resize",{"width":17,"height":11})
	for a in w.data.actors:a.x=4;a.y=4
	w.actor("hero2").x=3;w.actor("hero2").y=5;w.actor("hero3").x=5;w.actor("hero3").y=5;w.actor("hero4").x=4;w.actor("hero4").y=6
	for x in range(2,15):
		for y in range(2,9):w.scene().tiles[w.cell_key(x,y)]=1
	for x in range(1,16):w.command("tile",{"x":x,"y":1,"tile":3});w.command("tile",{"x":x,"y":9,"tile":3})
	for y in range(2,9):
		for x in [1,8,15]:w.command("tile",{"x":x,"y":y,"tile":3})
	w.command("tile",{"x":8,"y":5,"tile":6});w.command("tile",{"x":4,"y":1,"tile":6});w.command("tile",{"x":3,"y":3,"tile":7})
	var foe=w.read_json("res://assets/starter.json",{}).actors[4].duplicate(true);foe.id="hidden_guard";foe.scene=w.data.scene;foe.x=11;foe.y=5;w.data.actors.append(foe)
	w.mark_changed();await frames();b.set_view("Isometric");await frames()
	check(is_equal_approx(b.terrain.get_node("Door_8,5").rotation.y,PI/2),"3D door aligns with north/south wall")
	check(b.terrain.has_node("Wall_1,1"),"Connected corner masonry built")
	var pos=b.project(Vector3(4.5,0,4.5));var yaw_before=b.yaw;var pitch_before=b.pitch;var ping_before=w.ping_time;var hero_before=Vector2i(w.actor("hero1").x,w.actor("hero1").y)
	b.tool="Paint";b.tile=3;var tiles_before=w.scene().tiles.hash()
	button(pos,true,true)
	var motion=InputEventMouseMotion.new();motion.position=pos+Vector2(65,20);motion.relative=Vector2(65,20);b._gui_input(motion)
	button(motion.position,false,false)
	check(not is_equal_approx(b.yaw,yaw_before) and not is_equal_approx(b.pitch,pitch_before),"Shift + left drag orbits isometric camera")
	check(not b.rotating and not b.painting and b.drag_id=="","Releasing mouse after Shift release ends rotation cleanly")
	check(w.scene().tiles.hash()==tiles_before and w.ping_time==ping_before and Vector2i(w.actor("hero1").x,w.actor("hero1").y)==hero_before,"Camera gesture does not paint, move a hero or send a ping")
	b.tool="Select";b.set_view("Isometric");await frames()
	root.get_texture().get_image().save_png("user://rooms_dm.png")
	w.preview=true;w.mark_changed();await frames()
	check(b.actors.size()==4 and not b.actors.has("hidden_guard"),"Player rendering excludes concealed enemy model")
	check(not has_option(app.side,"Goblin Lookout"),"Player preview also excludes concealed attack targets")
	check(b.terrain.has_node("RoomAndManualFog"),"Opaque concealment mesh created")
	check(not b.terrain.has_node("Wall_15,5"),"Concealed terrain props are not instantiated")
	root.get_texture().get_image().save_png("user://rooms_closed.png")
	var door_pos=b.project(Vector3(8.5,0,5.5));button(door_pos,true);button(door_pos,false);await frames()
	check(w.scene().doors_open.get("8,5",false),"Clicking a visible door opens it")
	check(b.actors.has("hidden_guard"),"Opening a door reveals newly visible miniature")
	check(absf(b.terrain.get_node("Door_8,5/Leaf").rotation.y)>1,"Open door leaf visibly swings out")
	root.get_texture().get_image().save_png("user://rooms_open.png")
	w.selected="hidden_guard";app.refresh();await frames()
	button(door_pos,true);button(door_pos,false);await frames()
	check(not b.actors.has("hidden_guard"),"Closing door removes hidden model immediately")
	check(w.selected!="hidden_guard","Closing door clears a newly concealed inspector selection")
	# Imported images must not show through the opaque room masks.
	var image=Image.create(256,256,false,Image.FORMAT_RGBA8);image.fill(Color.RED)
	w.command("image",{"image":Marshalls.raw_to_base64(image.save_png_to_buffer())});b.set_view("Top down");await frames()
	var at=b.project(Vector3(11.5,0.11,5.5));var image3d=b.viewport.get_texture().get_image();var sample=at*Vector2(b.viewport.size)/b.size
	var color=image3d.get_pixel(clampi(int(sample.x),0,image3d.get_width()-1),clampi(int(sample.y),0,image3d.get_height()-1))
	check(color.r<0.12 and color.b<0.2,"Concealment covers imported image without seams or image bleed")
	w.preview=false;w.command("image",{"image":""});await frames()
	# A fast wall stroke must fill every skipped square, with edge-connected joins.
	b.tool="Paint";b.tile=3;b.last_painted=Vector2i(-1,-1);b.paint(Vector2i(2,10));b.paint_segment(Vector2i(7,10))
	var continuous=true
	for x in range(2,8):continuous=continuous and int(w.scene().tiles.get(w.cell_key(x,10),0))==3
	check(continuous,"Fast wall strokes fill skipped grid squares")
	b.last_painted=Vector2i(-1,-1);b.tool="Select";app.show_map_settings();await frames()
	root.get_texture().get_image().save_png("user://rooms_settings.png");app.close_modal()
	print("ROOM_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed")
	quit(1 if failed else 0)
