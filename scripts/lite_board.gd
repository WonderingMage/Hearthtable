extends "res://scripts/tabletop3d.gd"
## Both roles inspect the isometric tabletop. Players drag only their own pawns.
func set_view(_mode: String):
	camera_mode="Isometric";dirty=true;terrain_signature="";rotating=false;panning=false;pitch=.80;yaw=.55;fit_map()
func _process(delta):
	super._process(delta)
	view_container.visible=not obscured()
	if World.client and not drag_id.is_empty():
		var a=World.actor(drag_id);var status=World.lite.movement_status(a)
		if obscured() or a.is_empty() or not World.can_control(a) or a.scene!=World.data.scene or (status.combat and not status.turn):drag_id=""
func obscured() -> bool:
	return (World.client or World.preview) and (World.lite.blackout() or (World.client and not World.scene_sync.ready))
func _gui_input(event):
	if input_locked or World.scene_loading:return
	if World.client or World.preview:
		if obscured():return
		if event is InputEventMouseMotion:
			if rotating:yaw-=event.relative.x*.008;pitch=.8;update_camera()
			elif panning:target+=ground_at(event.position-event.relative)-ground_at(event.position);update_camera()
			hover=cell_at(event.position)
			if not drag_id.is_empty():
				drag_cell=hover-grab_offset;var route=World.lite.movement_route(World.actor(drag_id),drag_cell)
				map_hint.emit(str(route.reason)+" · "+World.COMBAT.distance_text(float(route.cost))+" ft")
			if ruler_start.x>=0:map_hint.emit(World.format_distance(World.measure_cells(ruler_start,hover))+" · measurement only")
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
				extent=clampf(extent*(.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/.88),4,90);update_camera()
			elif event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT] or (event.button_index==MOUSE_BUTTON_LEFT and event.shift_pressed):
				rotating=event.pressed and (event.shift_pressed or event.alt_pressed);panning=event.pressed and not rotating;rotation_button=event.button_index
			elif event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed and tool=="Measure":ruler_start=cell_at(event.position)
				elif event.pressed and World.client and tool=="Select":
					var cell=cell_at(event.position);var a=actor_at(event.position,cell)
					if not a.is_empty() and a.hero and World.can_control(a) and not a.get("public_token",false):
						World.selected=a.id;token_selected.emit(a.id)
						var status=World.lite.movement_status(a)
						if status.combat and not status.turn:World.message.emit("Wait for your turn to move.");return
						drag_id=a.id;grab_offset=cell-Vector2i(a.x,a.y);drag_cell=Vector2i(a.x,a.y)
				elif not event.pressed:
					if World.client and not drag_id.is_empty() and valid_cell(drag_cell):World.command("move",{"id":drag_id,"x":drag_cell.x,"y":drag_cell.y})
					drag_id="";ruler_start=Vector2i(-1,-1)
		return
	super._gui_input(event)
	if not drag_id.is_empty():
		var unit=World.actor(drag_id)
		if not unit.is_empty():map_hint.emit(unit.name+" · "+World.format_distance(World.measure_cells(Vector2i(unit.x,unit.y),drag_cell))+" · free DM placement")
func draw_overlay():
	if obscured():
		overlay.draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		draw_text(size/2,"The DM has obscured the table",22,Color("e1c184"),true);return
	super.draw_overlay()
func create_mini(a: Dictionary) -> Node3D:
	return super.create_mini(World.lite.token(a) if World.preview else a)
func draw_ruler(start: Vector2i,end: Vector2i,moving: bool):
	if not World.client or not moving:super.draw_ruler(start,end,moving);return
	var route=World.lite.movement_route(World.actor(drag_id),end);var color=Color("9bd2b0") if route.ok else Color("ee929d");var previous=project(Vector3(start.x+.5,.12,start.y+.5))
	for point in route.path:
		var next=project(Vector3(point.x+.5,.12,point.y+.5));overlay.draw_line(previous,next,color,3,true);previous=next
	var status=World.lite.movement_status(World.actor(drag_id))
	draw_text(project(Vector3(end.x+.5,.12,end.y+.5))+Vector2(0,-18),World.COMBAT.distance_text(float(route.cost))+" ft"+(" · "+World.COMBAT.distance_text(float(status.remaining))+" ft remaining" if status.combat else " · exploration"),14,color,true)
