extends Control

signal token_selected(id: String)
signal map_hint(text: String)
signal target_selected(id: String)
signal ground_selected(cell: Vector2i)
signal tactical_cancelled
signal tactical_hovered(id: String)
var tool="Select"
var tile=1
var grid=true
var labels=true
var coordinates=true
var cutaway=true
var render_scale=1.0
var zoom=1.0
var hover=Vector2i(-1,-1)
var drag_id=""
var drag_cell=Vector2i(-1,-1)
var grab_offset=Vector2i.ZERO
var ruler_start=Vector2i(-1,-1)
var area_start=Vector2i(-1,-1)
var panning=false
var painting=false
var last_painted=Vector2i(-1,-1)
var rotating=false
var rotation_button=0
var attack_preview={}
var dirty=true
var terrain_signature=""
var last_scene=""
var target=Vector3(12,0,7)
var yaw=0.22
var pitch=0.78
var extent=18.0
var fitted_extent=18.0
var elapsed=0.0
var viewport: SubViewport
var view_container: TextureRect
var camera: Camera3D
var stage: Node3D
var terrain: Node3D
var minis: Node3D
var actors: Dictionary={}
var model_cache: Dictionary={}
var material_cache: Dictionary={}
var floor_texture: Texture2D
var map_image=""
var overlay: Control
var bold: Font=preload("res://assets/Inter.ttf")
var regular: Font=preload("res://assets/Inter.ttf")
const BLUE=Color("91bcff")
var camera_mode="Isometric"
var build_controller
const BUILD=preload("res://scripts/build_system.gd")
const BUILD_MODELS=preload("res://scripts/build_models.gd")
var pov_actor_id=""
var pov_yaw=0.0
var look_pitch=-0.08
var follow_distance=4.0
var pov_fov=70.0
var input_locked=false
var enemy_hud=false
var zones_controller
var lighting
var targeting=false
var target_id=""
var spell_preview={}
var elevation_brush_ft=5.0
var last_client=false
var world_environment: WorldEnvironment
var sky: Sky
var float_events=[]
var seen_events={}
var move_cooldown=0.0
var preview_root: Node3D
var preview_signature=""
var tactical_focus=Vector3.ZERO
var tactical_distance=11.0
var tactical_pitch=0.88
var tactical_yaw=0.35
var tactical_tracking=true
var tactical_actor=""
var tactical_top=false
var movement_preview={}
var movement_signature=""
var hover_actor_id=""
var route_tick=0.0
var patch_material: ShaderMaterial
func immersive() -> bool:return camera_mode=="Tactical"
func pov_actor() -> Dictionary:
	var a=World.actor(pov_actor_id)
	if a.is_empty() or not World.can_control(a) or not a.hero or a.scene!=World.data.scene:
		for unit in World.data.actors:
			if unit.hero and unit.scene==World.data.scene and World.can_control(unit):pov_actor_id=unit.id;return unit
		return {}
	return a
func floor_y(a: Dictionary) -> float:return float(a.get("elevation_ft",0))/maxf(0.1,World.encounter.feet_per_cell())
func eye_y(a: Dictionary) -> float:return (5.25*minf(float(a.get("token_size",1)),2.0))/maxf(0.1,World.encounter.feet_per_cell())


func _ready():
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL
	view_container=TextureRect.new();view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view_container.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view_container.stretch_mode=TextureRect.STRETCH_SCALE;view_container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(view_container)
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;viewport.transparent_bg=false;viewport.positional_shadow_atlas_size=2048;add_child(viewport);view_container.texture=viewport.get_texture()
	stage=Node3D.new();viewport.add_child(stage)
	world_environment=WorldEnvironment.new();var env=Environment.new()
	sky=Sky.new();var sky_material=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("496b96");sky_material.sky_horizon_color=Color("b0c8d8");sky_material.ground_bottom_color=Color("283c40");sky_material.ground_horizon_color=Color("b0c8d8");sky.sky_material=sky_material;env.sky=sky
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("151a25");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b4c9e6");env.ambient_light_energy=0.30
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world_environment.environment=env;stage.add_child(world_environment)
	var sun=DirectionalLight3D.new();sun.name="Sun";sun.rotation_degrees=Vector3(-48,-25,0);sun.light_color=Color("fff0d4");sun.light_energy=0.85;sun.shadow_enabled=true;sun.directional_shadow_max_distance=80;sun.shadow_bias=0.06;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;stage.add_child(sun)
	var fill=DirectionalLight3D.new();fill.name="Fill";fill.rotation_degrees=Vector3(-35,145,0);fill.light_color=Color("91b9f2");fill.light_energy=0.18;stage.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=0.05;camera.far=180;stage.add_child(camera);camera.current=true
	terrain=Node3D.new();stage.add_child(terrain);minis=Node3D.new();stage.add_child(minis);preview_root=Node3D.new();stage.add_child(preview_root)
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.draw.connect(draw_overlay);add_child(overlay)
	lighting=preload("res://scripts/scene_lighting.gd").new(self);lighting.setup()
	World.changed.connect(func():dirty=true)
	resized.connect(resize_view)
	call_deferred("resize_view");call_deferred("set_view","Isometric")

func resize_view():
	if not is_instance_valid(viewport):return
	var dpi_factor=float(get_tree().root.content_scale_factor)
	viewport.size=Vector2i(maxi(1,int(round(size.x*dpi_factor*render_scale))),maxi(1,int(round(size.y*dpi_factor*render_scale))))
	viewport.scaling_3d_scale=1.0
	update_camera();overlay.queue_redraw()

func _process(delta):
	if lighting!=null:lighting.process(delta)
	elapsed+=delta;move_cooldown=maxf(0,move_cooldown-delta)
	if World.client!=last_client:
		last_client=World.client
		set_view("Tactical" if World.client else "Isometric")
	if immersive():
		var selected=World.actor(World.selected)
		if not selected.is_empty() and selected.hero and selected.scene==World.data.scene and World.can_control(selected):pov_actor_id=selected.id

	if dirty:sync_state();dirty=false
	for id in actors:
		var root=actors[id]
		var a=World.actor(id)
		if a.is_empty():continue
		var cell=Vector2(drag_cell) if drag_id==id else Vector2(a.x,a.y)
		var footprint=float(a.get("token_size",1))
		var desired=Vector3(cell.x+footprint/2,0.055+floor_y(a),cell.y+footprint/2)
		var logical=Vector2i(a.x,a.y)
		if root.get_meta("logical_cell",logical)!=logical:
			var path=root.get_meta("waypoints",[])
			for point in a.get("last_path",[]):path.append(Vector3(float(point.x)+footprint/2,0.055+World.encounter.elevation(Vector2i(point.x,point.y))/World.encounter.feet_per_cell(),float(point.y)+footprint/2))
			root.set_meta("waypoints",path);root.set_meta("logical_cell",logical)
		var waypoints=root.get_meta("waypoints",[])
		var visual_target=waypoints[0] if not waypoints.is_empty() else desired
		var was_moving=root.position.distance_to(visual_target)>0.02
		if drag_id==id:root.position=desired
		else:root.position=root.position.move_toward(visual_target,delta*6.0)
		if not waypoints.is_empty() and root.position.distance_to(visual_target)<0.02:waypoints.pop_front();root.set_meta("waypoints",waypoints)
		var figure=root.get_node_or_null("Figure")
		if figure and a.hp>0:
			figure.position.y=-0.045 if immersive() else 0.10
			if immersive() and camera_mode!="Tactical" and id==pov_actor_id:figure.rotation.y=lerp_angle(figure.rotation.y,pov_yaw+PI,minf(1,delta*12))
			elif was_moving:figure.rotation.y=lerp_angle(figure.rotation.y,atan2(visual_target.x-root.position.x,visual_target.z-root.position.z),minf(1,delta*12))
		var animator=root.get_meta("animator") if root.has_meta("animator") else null
		if animator!=null and elapsed>float(root.get_meta("attacking_until",0)):
			var anim_name=str(root.get_meta("walk_anim","")) if was_moving else str(root.get_meta("idle_anim",""))
			if not anim_name.is_empty() and animator.current_animation!=anim_name:animator.play(anim_name,0.1)
		root.visible=not (camera_mode=="First person" and id==pov_actor_id)
		for index in [0,1]:
			if index<root.get_child_count():root.get_child(index).visible=not immersive()
		var ring=root.get_node_or_null("Selection")
		if ring:ring.visible=(id in [target_id,pov_actor_id] if immersive() else id==World.selected)
	if camera_mode=="Tactical":process_tactical(delta)
	elif immersive():update_camera()
	if str(spell_preview.hash())!=preview_signature:preview_signature=str(spell_preview.hash());build_spell_preview()
	for event in float_events:event.age+=delta
	float_events=float_events.filter(func(e):return e.age<2.6)
	for event in World.data.get("resolutions",[]):
		if seen_events.has(event.id):continue
		seen_events[event.id]=true
		if event.get("scene","")==World.data.scene and event.kind in ["attack","damage","heal","save","effect"]:
			var e=event.duplicate(true);e.age=0.0;float_events.append(e)
			if event.kind=="attack":play_attack(event)
	if seen_events.size()>300:seen_events.clear()
	if is_instance_valid(overlay):overlay.queue_redraw()

func fit_map():
	if immersive():update_camera();return
	if not is_inside_tree() or World.data.is_empty() or camera==null:return
	var s=World.scene();target=Vector3(float(s.width)/2,0,float(s.height)/2)
	var aspect=maxf(0.5,size.x/maxf(1,size.y))
	var span_x=absf(cos(yaw))*s.width+absf(sin(yaw))*s.height
	var span_y=(absf(sin(yaw))*s.width+absf(cos(yaw))*s.height)*sin(pitch)+2.0
	extent=maxf(span_y,span_x/aspect)*1.12;fitted_extent=extent;zoom=1.0;update_camera()

func focus_selected():
	if immersive():
		pov_actor_id=World.selected;tactical_tracking=true;update_camera();return
	var a=World.actor(World.selected)
	if a.is_empty():return
	target=Vector3(a.x+0.5,0,a.y+0.5);extent=10.0;zoom=fitted_extent/extent;update_camera()

func set_view(mode: String):
	mode="Tactical" if World.client else "Isometric"
	camera_mode=mode;dirty=true;terrain_signature="";rotating=false;panning=false;movement_signature="";movement_preview={};tactical_tracking=true
	if immersive():
		pov_actor_id=World.selected;pov_actor();update_camera();return
	if mode=="Top down":pitch=PI/2-0.001;yaw=0.0
	elif mode=="Isometric":pitch=0.80;yaw=0.55
	else:pitch=0.86;yaw=0.12
	fit_map()

func update_camera():
	if camera==null:return
	if immersive():
		var a=pov_actor()
		if a.is_empty():camera.projection=Camera3D.PROJECTION_ORTHOGONAL;return
		camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=pov_fov;camera.near=0.04
		var center=actors[a.id].position if actors.has(a.id) else Vector3(a.x+0.5,floor_y(a),a.y+0.5)
		if camera_mode=="Tactical":
			if tactical_actor!=a.id:tactical_actor=a.id;tactical_focus=center;tactical_tracking=true
			var angle=1.49 if tactical_top else tactical_pitch
			camera.fov=48;camera.position=tactical_focus+Vector3(sin(tactical_yaw)*cos(angle),sin(angle),cos(tactical_yaw)*cos(angle))*tactical_distance
			camera.look_at(tactical_focus,Vector3.UP);world_environment.environment.background_mode=Environment.BG_SKY;return
		var eye=center+Vector3.UP*eye_y(a)
		var direction=Vector3(-sin(pov_yaw)*cos(look_pitch),sin(look_pitch),-cos(pov_yaw)*cos(look_pitch))
		if camera_mode=="First person":camera.position=eye;camera.look_at(eye+direction,Vector3.UP)
		else:
			var focus=eye-Vector3.UP*0.2
			var desired=focus+Vector3(sin(pov_yaw)*cos(0.42),sin(0.42),cos(pov_yaw)*cos(0.42))*follow_distance
			var safe=focus
			for step in range(1,31):
				var sample=focus.lerp(desired,step/30.0);var cell=Vector2i(floor(sample.x),floor(sample.z))
				if World.ROOMS.blocked(World.scene(),cell) or not World.cell_visible(cell):break
				safe=sample
			camera.position=safe;camera.look_at(focus+direction*1.5,Vector3.UP)
		world_environment.environment.background_mode=Environment.BG_SKY
		return
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world_environment.environment.background_mode=Environment.BG_COLOR
	camera.size=extent
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*45
	camera.look_at(target,Vector3.UP)

func project(point: Vector3) -> Vector2:
	var p=camera.unproject_position(point)
	return p*size/Vector2(viewport.size)

func ground_at(pos: Vector2) -> Vector3:
	if camera==null:return Vector3(-999,0,-999)
	var p=pos*Vector2(viewport.size)/Vector2(maxf(1,size.x),maxf(1,size.y))
	var hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(p),camera.project_ray_normal(p))
	var closest=hit if hit!=null else Vector3(-999,0,-999)
	var ray_origin=camera.project_ray_origin(p);var ray_direction=camera.project_ray_normal(p)
	var best=ray_origin.distance_to(closest) if hit!=null else INF
	for key in World.scene().get("elevations",{}):
		var xy=str(key).split(",")
		var height=float(World.scene().elevations[key])/maxf(0.1,World.encounter.feet_per_cell())
		var top=Plane(Vector3.UP,height).intersects_ray(ray_origin,ray_direction)
		if top!=null and floor(top.x)==float(xy[0]) and floor(top.z)==float(xy[1]) and ray_origin.distance_to(top)<best:closest=top;best=ray_origin.distance_to(top)
	return closest

func cell_at(pos: Vector2) -> Vector2i:
	var p=ground_at(pos);return Vector2i(floor(p.x),floor(p.z))

func valid_cell(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<int(World.scene().width) and cell.y<int(World.scene().height)

func paint(cell: Vector2i):
	if not World.is_dm() or World.preview or not valid_cell(cell):return
	if cell==last_painted:return
	last_painted=cell
	if tool=="Elevation":World.command("elevation",{"x":cell.x,"y":cell.y,"feet":elevation_brush_ft})
	elif tool in ["Reveal","Conceal"]:World.command("fog",{"x":cell.x,"y":cell.y,"hide":tool=="Conceal"})
	elif tool=="Paint":World.command("tile",{"x":cell.x,"y":cell.y,"tile":tile})

func paint_segment(cell: Vector2i):
	# Fast wall strokes stay edge-connected even when mouse events skip squares.
	if tool!="Paint" or tile!=3 or last_painted.x<0:paint(cell);return
	var p=last_painted;var delta=cell-p;var nx=absi(delta.x);var ny=absi(delta.y);var ix=0;var iy=0
	while ix<nx or iy<ny:
		if ix<nx and (iy>=ny or (1+2*ix)*ny<=(1+2*iy)*nx):p.x+=signi(delta.x);ix+=1
		else:p.y+=signi(delta.y);iy+=1
		paint(p)

func actor_at(pos: Vector2,cell: Vector2i) -> Dictionary:
	var best={};var nearest=9999.0
	for a in World.data.actors:
		if a.scene!=World.data.scene or ((World.preview or World.client or immersive()) and not World.visible(a)):continue
		var footprint=float(a.get("token_size",1))
		var foot=Vector3(a.x+footprint/2,0,a.y+footprint/2)
		var center=project(foot+Vector3.UP*0.5*minf(footprint,2))
		var radius=maxf(15.0,project(foot+Vector3.RIGHT*footprint*0.45).distance_to(project(foot)))
		var distance=center.distance_to(pos)
		if distance<radius*1.1 and distance<nearest:best=a;nearest=distance
	if not best.is_empty():return best
	for a in World.data.actors:
		if a.scene!=World.data.scene or ((World.preview or World.client or immersive()) and not World.visible(a)):continue
		var t=int(a.get("token_size",1))
		if cell.x>=a.x and cell.x<a.x+t and cell.y>=a.y and cell.y<a.y+t:return a
	return {}

func _input(event):
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE] or (camera_mode=="Tactical" and event.button_index==rotation_button):rotating=false;panning=false

func _gui_input(event):
	if input_locked or World.scene_loading:return
	if camera_mode=="Tactical":tactical_input(event);return
	if zones_controller!=null and zones_controller.handle(event):return
	if build_controller!=null and build_controller.handle(event):return
	if immersive():immersive_input(event);return
	if event is InputEventMouseMotion:
		if rotating:
			yaw-=event.relative.x*0.008;pitch=0.80;update_camera()
		elif panning:
			var before=ground_at(event.position-event.relative);var after=ground_at(event.position);target+=before-after;update_camera()
		hover=cell_at(event.position)
		if drag_id!="":drag_cell=hover-grab_offset
		if painting and valid_cell(hover):paint_segment(hover)
		if valid_cell(hover):
			var hint="Square "+Rules5e.column_name(hover.x)+str(hover.y+1)+"  ·  "+World.format_distance(World.grid_settings().distance)+" / square"
			if int(World.scene().tiles.get(World.cell_key(hover.x,hover.y),0))==6 and (World.is_dm() and not World.preview or World.cell_visible(hover)):
				hint+="  ·  Door "+("open" if World.scene().get("doors_open",{}).get(World.cell_key(hover.x,hover.y),false) else "closed")+(" · Walk through; E or Door closes" if World.scene().get("doors_open",{}).get(World.cell_key(hover.x,hover.y),false) else " · Click to open")
			map_hint.emit(hint)
		if ruler_start.x>=0:map_hint.emit(World.format_distance(World.measure_cells(ruler_start,hover))+"  ·  "+str(maxi(absi(hover.x-ruler_start.x),absi(hover.y-ruler_start.y)))+" squares")
	if not event is InputEventMouseButton:return
	if rotating and event.button_index==rotation_button and not event.pressed:
		rotating=false;rotation_button=0;return
	if event.pressed and event.shift_pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
		rotating=true;rotation_button=event.button_index;panning=false;return
	var cell=cell_at(event.position)
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		var before=ground_at(event.position)
		extent=clampf(extent*(0.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/0.88),4.0,90.0);zoom=fitted_extent/extent;update_camera()
		var after=ground_at(event.position);target+=before-after;update_camera();return
	if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:
		panning=event.pressed and not event.alt_pressed;rotating=event.pressed and event.alt_pressed;rotation_button=event.button_index if rotating else 0;return
	if event.button_index!=MOUSE_BUTTON_LEFT:return
	if enemy_hud and targeting:
		if event.pressed:
			var victim=actor_at(event.position,cell)
			if not victim.is_empty():target_id=victim.id;target_selected.emit(victim.id)
			elif valid_cell(cell):ground_selected.emit(cell)
		return
	if event.pressed:
		if not valid_cell(cell):return
		if tool=="Ping":World.command("ping",{"x":cell.x,"y":cell.y});return
		if tool=="Measure":ruler_start=cell;return
		if tool in ["Circle","Cone","Square"]:area_start=cell;return
		if tool in ["Paint","Reveal","Conceal","Elevation"]:painting=true;paint(cell);return
		if int(World.scene().tiles.get(World.cell_key(cell.x,cell.y),0))==6 and not World.scene().get("doors_open",{}).get(World.cell_key(cell.x,cell.y),false):
			if World.client and not World.cell_visible(cell):return
			if World.client:
				var hero=World.actor(World.selected)
				if not World.can_control(hero) or hero.scene!=World.data.scene or hero.hp<=0:
					World.message.emit("Select an active hero assigned to you before opening a door.");return
				var near=false
				for dx in int(hero.get("token_size",1)):
					for dy in int(hero.get("token_size",1)):
						var diff=cell-Vector2i(int(hero.x)+dx,int(hero.y)+dy)
						if maxi(absi(diff.x),absi(diff.y))<=1:near=true
				if not near:World.message.emit("Move your assigned hero next to the door first.");return
			World.command("door",{"id":World.selected,"x":cell.x,"y":cell.y});return
		var a=actor_at(event.position,cell)
		if not a.is_empty():
			World.selected=a.id;token_selected.emit(a.id)
			if World.can_control(a):drag_id=a.id;grab_offset=cell-Vector2i(a.x,a.y);drag_cell=Vector2i(a.x,a.y)
	else:
		painting=false;last_painted=Vector2i(-1,-1)
		if area_start.x>=0 and valid_cell(cell):World.command("template",{"id":World.selected,"shape":tool,"x":area_start.x,"y":area_start.y,"ex":cell.x,"ey":cell.y})
		area_start=Vector2i(-1,-1)
		if drag_id!="" and valid_cell(drag_cell):World.command("move",{"id":drag_id,"x":drag_cell.x,"y":drag_cell.y,"dm_override":World.is_dm() and event.ctrl_pressed})
		drag_id="";ruler_start=Vector2i(-1,-1)

func mat(color: Color,metallic: float=0.0,glow: float=0.0) -> StandardMaterial3D:
	var key=color.to_html()+str(metallic)+str(glow)
	if material_cache.has(key):return material_cache[key]
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.82;m.metallic=metallic
	if glow>0:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	if color.a<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material_cache[key]=m;return m

func box(parent: Node3D,pos: Vector3,dims: Vector3,color: Color) -> MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=dims;n.mesh=mesh;n.material_override=mat(color);n.position=pos;parent.add_child(n);return n

func cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,color: Color,top: float=-1) -> MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=radius if top<0 else top;mesh.height=height;mesh.radial_segments=16;n.mesh=mesh;n.material_override=mat(color);n.position=pos;parent.add_child(n);return n

func sphere(parent: Node3D,pos: Vector3,radius: float,color: Color) -> MeshInstance3D:
	var n=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=16;mesh.rings=8;n.mesh=mesh;n.material_override=mat(color);n.position=pos;parent.add_child(n);return n

func model(parent: Node3D,name_model: String,pos: Vector3,scale_model: Vector3=Vector3.ONE,angle: float=0) -> Node3D:
	var path="res://assets/models/"+name_model+".glb"
	if not model_cache.has(path):model_cache[path]=load(path)
	if model_cache[path]==null:return Node3D.new()
	var n=model_cache[path].instantiate();parent.add_child(n);n.position=pos;n.scale=scale_model;n.rotation.y=angle;return n

func clear_node(node: Node):
	for child in node.get_children():node.remove_child(child);child.queue_free()

func sync_state():
	var s=World.scene()
	World.refresh_rooms()
	var mask=s.get("room_mask",{}) if World.client else World.room_info.concealed
	var sig=str([s.id,s.tiles.hash(),s.fog.hash(),mask.hash(),s.get("doors_open",{}).hash(),World.preview,World.client,s.get("image","").hash(),cutaway,grid,camera_mode,s.get("wall_height_ft",10),s.get("elevations",{}).hash(),s.get("grid_pixels",0),s.get("grid_offset_x",0),s.get("grid_offset_y",0),s.width,s.height,s.get("props",[]).hash(),s.get("surfaces",{}).hash(),s.get("asset_pack",[]).hash(),s.get("terrain_blocks",{}).hash(),s.get("preserve_map_art",false)])
	if terrain_signature!=sig:terrain_signature=sig;build_terrain();lighting.rebuild()
	if last_scene!=s.id:
		last_scene=s.id;clear_node(minis);actors={};movement_preview={};movement_signature="";tactical_actor="";tactical_tracking=true;attack_preview={};spell_preview={};target_id="";targeting=false;fit_map();float_events=[];tactical_cancelled.emit()
		for event in World.data.get("resolutions",[]):seen_events[event.id]=true
	var alive={}
	for a in World.data.actors:
		if a.scene!=s.id or ((World.client or World.preview or immersive()) and not World.visible(a)):continue
		alive[a.id]=true
		var signature=str([a.get("miniature","Auto"),a.class,a.race,a.color,a.get("token_size",1),a.hp<=0])
		if actors.has(a.id) and actors[a.id].get_meta("signature","")!=signature:
			minis.remove_child(actors[a.id]);actors[a.id].queue_free();actors.erase(a.id)
		if not actors.has(a.id):
			var mini=create_mini(a);mini.set_meta("signature",signature);actors[a.id]=mini
	for id in actors.keys():
		if not alive.has(id):minis.remove_child(actors[id]);actors[id].queue_free();actors.erase(id)

func build_terrain():
	clear_node(terrain)
	var s=World.scene();var w=float(s.width);var h=float(s.height)
	var floor_transforms=[];var floor_colors=[];var fog_transforms=[]
	box(terrain,Vector3(w/2,-0.30,h/2),Vector3(w+0.35,0.44,h+0.35),Color("242932"))
	box(terrain,Vector3(w/2,-0.10,h/2),Vector3(w+0.18,0.09,h+0.18),Color("635741"))
	box(terrain,Vector3(w/2,-0.045,h/2),Vector3(w,0.08,h),Color("414a43"))
	var imported=str(s.get("image",""))
	if not imported.is_empty():build_image(imported,s)
	for x in int(w):
		for y in int(h):
			var key=World.cell_key(x,y);var cell_pos=Vector3(x+0.5,0,y+0.5)
			if not World.cell_visible(Vector2i(x,y)) and (World.client or World.preview or immersive()):
				fog_transforms.append(Transform3D(Basis.IDENTITY,cell_pos+Vector3.UP*(float(s.get("wall_height_ft",10))/World.encounter.feet_per_cell()/2 if immersive() else 0.045)));continue
			var elevation=float(s.get("elevations",{}).get(key,0))/maxf(0.1,World.encounter.feet_per_cell());cell_pos.y=elevation
			if elevation>0:
				box(terrain,Vector3(x+0.5,elevation/2,y+0.5),Vector3(0.998,elevation,0.998),Color("666f71"))
				if not imported.is_empty():elevated_image(cell_pos,s)
			var t=int(s.tiles.get(key,0));var random_value=absf(sin(x*31.13+y*71.77))
			if imported.is_empty() or (s.tiles.has(key) and not s.get("preserve_map_art",false)) or (elevation>0 and imported.is_empty()) or (s.get("surfaces",{}).has(key) and not (s.get("preserve_map_art",false) and s.surfaces[key]=="lava")):
				var floor_color=Color("56644d") if s.theme!="blank" else Color("535965")
				if t in [1,3,6,7,8]:floor_color=Color("727970")
				if t==2:floor_color=Color("886948")
				if t==4:floor_color=Color("356576")
				var surface=BUILD.definition(str(s.get("surfaces",{}).get(key,"")))
				if not surface.is_empty():floor_color=Color(surface.color)
				floor_color=floor_color.lightened(random_value*0.06)
				floor_transforms.append(Transform3D(Basis.IDENTITY,cell_pos-Vector3.UP*0.025));floor_colors.append(floor_color)
			var surface_asset=str(s.get("surfaces",{}).get(key,""))
			if surface_asset in ["water","deep-water","lava","ice"] and not s.get("preserve_map_art",false):BUILD_MODELS.water(terrain,cell_pos+Vector3.UP*.012,Vector3(.99,.018,.99),Color(BUILD.definition(surface_asset).color))
			match t:
				1:
					if (x*7+y)%19==0:model(terrain,"stones",cell_pos,Vector3.ONE*0.3,random_value*6)
				2:
					for off in [-0.24,0.24]:box(terrain,cell_pos+Vector3(off,0.004,0),Vector3(0.008,0.01,0.95),Color("473b31"))
				3:
					build_wall(cell_pos,Vector2i(x,y))
				4:
					for off in [-0.22,0.13]:box(terrain,cell_pos+Vector3(0,0.008,off),Vector3(0.48,0.01,0.016),Color("75a7ae"))
				5:build_tree(cell_pos,random_value)
				6:build_door(cell_pos,Vector2i(x,y))
				7:build_torch(cell_pos)
				9:
					var rock=sphere(terrain,cell_pos+Vector3.UP*0.62,0.63,Color("7b858c"));rock.scale=Vector3(0.85,1.15,0.9)
				10:box(terrain,cell_pos+Vector3.UP*0.08,Vector3(0.98,0.16,0.98),Color("939388"))
				11:
					if not (not imported.is_empty() and s.get("preserve_map_art",false)):
						for step in 4:box(terrain,cell_pos+Vector3(0,0.06+step*0.09,-0.375+step*0.25),Vector3(0.98,0.12+step*0.18,0.25),Color("8e938e"))
				12:
					for piece in 5:model(terrain,"stones",cell_pos+Vector3(sin(piece*9)*0.3,0,cos(piece*8)*0.3),Vector3.ONE*0.23,piece)
				13:model(terrain,"column",cell_pos,Vector3(0.75,1.1,0.75))
				8:
					if s.theme=="tavern":
						model(terrain,"table",cell_pos,Vector3.ONE*1.35)
						model(terrain,"chair",cell_pos+Vector3(0,0,0.6),Vector3.ONE*1.3)
					else:model(terrain,"chest",cell_pos,Vector3.ONE*1.2,0.12)
			if not World.cell_visible(Vector2i(x,y)):box(terrain,cell_pos+Vector3.UP*0.018,Vector3(1,0.025,1),Color(0.1,0.16,0.24,0.48))
	for prop in s.get("props",[]):
		var dims=BUILD.rect(prop);var visible=false
		for x in range(dims.position.x,dims.end.x):
			for y in range(dims.position.y,dims.end.y):
				if World.cell_visible(Vector2i(x,y)):visible=true
		if (World.client or World.preview) and not visible:continue
		var node=BUILD_MODELS.make(BUILD.definition(prop.asset),int(prop.swatch));node.name="Prop_"+str(prop.uid);terrain.add_child(node);node.position=Vector3(prop.x+dims.size.x/2.0,World.encounter.elevation(dims.position)/World.encounter.feet_per_cell(),prop.y+dims.size.y/2.0);node.rotation.y=int(prop.rotation)*PI/2
	# Freestanding props add readable height without blocking the play surface.
	if imported.is_empty() and s.theme in ["ruins","tavern"]:
		for point in [Vector3(4.5,0,4.5),Vector3(11.5,0,4.5),Vector3(14.5,0,1.5),Vector3(19.5,0,1.5)]:
			if not World.cell_visible(Vector2i(int(point.x),int(point.z))) and (World.client or World.preview or immersive()):continue
			model(terrain,"column",point,Vector3(0.7,0.62,0.7))
		for point in [Vector3(4.7,0,10.8),Vector3(5.4,0,10.8)]:
			if World.cell_visible(Vector2i(int(point.x),int(point.z))) or not (World.client or World.preview or immersive()):model(terrain,"barrel",point,Vector3.ONE*0.85)
	if not floor_transforms.is_empty():
		var floors=MultiMeshInstance3D.new();var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
		var geometry=BoxMesh.new();geometry.size=Vector3(0.978,0.05,0.978);batch.mesh=geometry;batch.instance_count=floor_transforms.size()
		for i in floor_transforms.size():batch.set_instance_transform(i,floor_transforms[i]);batch.set_instance_color(i,floor_colors[i])
		floors.multimesh=batch;var floor_mat=StandardMaterial3D.new();floor_mat.vertex_color_use_as_albedo=true;floor_mat.vertex_color_is_srgb=true;floor_mat.roughness=0.95;floors.material_override=floor_mat;terrain.add_child(floors)
	if grid and not immersive():build_grid(w,h)
	if not fog_transforms.is_empty():
		var fog=MultiMeshInstance3D.new();fog.name="RoomAndManualFog";var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D
		var geometry=BoxMesh.new();geometry.size=Vector3(1.002,float(s.get("wall_height_ft",10))/World.encounter.feet_per_cell() if immersive() else 0.12,1.002);batch.mesh=geometry;batch.instance_count=fog_transforms.size()
		for i in fog_transforms.size():batch.set_instance_transform(i,fog_transforms[i])
		fog.multimesh=batch;var material=StandardMaterial3D.new();material.albedo_color=Color("111824");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fog.material_override=material;terrain.add_child(fog)

func build_wall(pos: Vector3,cell: Vector2i):
	var root=Node3D.new();root.name="Wall_"+World.cell_key(cell.x,cell.y);root.position=pos;terrain.add_child(root)
	var joins=World.ROOMS.connections(World.scene(),cell)
	if joins.size()<2:
		var direction=Vector2i.RIGHT if joins.is_empty() else joins[0]
		joins=[direction,-direction]
	var h=0.65 if cutaway and (not immersive() or camera_mode=="Tactical") else float(World.scene().get("wall_height_ft",10))/maxf(0.1,World.encounter.feet_per_cell())
	box(root,Vector3(0,h/2,0),Vector3(0.25,h,0.25),Color("858b87"))
	for direction in joins:
		var off=Vector3(direction.x,0,direction.y)*0.25
		var dims=Vector3(0.51,h,0.23) if direction.x!=0 else Vector3(0.23,h,0.51)
		box(root,off+Vector3.UP*h/2,dims,Color("7b827f"))
		box(root,off+Vector3.UP*0.06,Vector3(dims.x+0.045,0.12,dims.z+0.045),Color("626b69"))
		box(root,off+Vector3.UP*(h+0.025),Vector3(dims.x+0.045,0.07,dims.z+0.045),Color("b1b3a6"))
		for level in range(1,3 if cutaway and (not immersive() or camera_mode=="Tactical") else 8):
			box(root,off+Vector3.UP*(level*0.25),Vector3(dims.x+0.002,0.012,dims.z+0.002),Color("535e5d"))

func build_door(pos: Vector3,cell: Vector2i):
	var root=Node3D.new();root.name="Door_"+World.cell_key(cell.x,cell.y);root.position=pos;root.rotation.y=World.ROOMS.door_angle(World.scene(),cell);terrain.add_child(root)
	var h=0.9 if cutaway and (not immersive() or camera_mode=="Tactical") else float(World.scene().get("wall_height_ft",10))/maxf(0.1,World.encounter.feet_per_cell())
	for x in [-0.44,0.44]:
		box(root,Vector3(x,h/2,0),Vector3(0.12,h,0.29),Color("a2a69d"))
		box(root,Vector3(x,0.065,0),Vector3(0.18,0.13,0.34),Color("626b69"))
	box(root,Vector3(0,h,0),Vector3(1.0,0.13,0.31),Color("b1b3a6"))
	var hinge=Node3D.new();hinge.name="Leaf";hinge.position=Vector3(-0.37,0,0);root.add_child(hinge)
	hinge.rotation.y=-PI*0.48 if World.scene().get("doors_open",{}).get(World.cell_key(cell.x,cell.y),false) else 0.0
	box(hinge,Vector3(0.37,(h-0.08)/2,0),Vector3(0.74,h-0.08,0.09),Color("926843"))
	for x in [0.15,0.3,0.45,0.6]:box(hinge,Vector3(x,(h-0.08)/2,-0.049),Vector3(0.009,h-0.12,0.009),Color("5d4935"))
	for y in [h*0.22,h*0.72]:box(hinge,Vector3(0.37,y,-0.055),Vector3(0.72,0.055,0.025),Color("48555e"))
	sphere(hinge,Vector3(0.63,h*0.45,-0.085),0.035,Color("e3b562"))

func build_image(encoded: String,s: Dictionary):
	var img=Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(encoded))!=OK:return
	img.generate_mipmaps();floor_texture=ImageTexture.create_from_image(img);patch_material=null
	var plane=MeshInstance3D.new();var mesh=PlaneMesh.new();mesh.size=Vector2(s.width,s.height);plane.mesh=mesh;plane.position=Vector3(s.width/2.0,0.002,s.height/2.0)
	var m=StandardMaterial3D.new();m.albedo_texture=floor_texture;m.roughness=1;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var pixels=float(s.get("grid_pixels",0))
	if pixels>0:
		var shader=Shader.new();shader.code="shader_type spatial; uniform sampler2D image_tex : source_color, filter_linear_mipmap_anisotropic; uniform sampler2D glow_mask : filter_nearest; uniform vec2 image_size; uniform vec2 board_size; uniform vec2 offset_px; uniform float pixels; void fragment(){vec2 p=(UV*board_size*pixels+offset_px)/image_size; ALBEDO=any(lessThan(p,vec2(0.0)))||any(greaterThan(p,vec2(1.0)))?vec3(0.12):texture(image_tex,p).rgb; float lava=texture(glow_mask,UV).r; EMISSION=ALBEDO*lava*(.65+.12*sin(TIME*1.3+UV.x*18.0)); ROUGHNESS=1.0;}"
		var sm=ShaderMaterial.new();sm.shader=shader;sm.set_shader_parameter("image_tex",floor_texture);sm.set_shader_parameter("image_size",Vector2(img.get_size()));sm.set_shader_parameter("board_size",Vector2(s.width,s.height));var mask=Image.create(int(s.width),int(s.height),false,Image.FORMAT_RGBA8);mask.fill(Color.BLACK)
		for key in s.get("surfaces",{}):
			if s.surfaces[key]=="lava":
				var xy=str(key).split(",");mask.set_pixel(int(xy[0]),int(xy[1]),Color.WHITE)
		sm.set_shader_parameter("glow_mask",ImageTexture.create_from_image(mask));sm.set_shader_parameter("pixels",pixels);sm.set_shader_parameter("offset_px",Vector2(s.get("grid_offset_x",0),s.get("grid_offset_y",0)));plane.material_override=sm
	else:plane.material_override=m
	terrain.add_child(plane)

func build_grid(w: float,h: float):
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(int(w)+1):mesh.surface_add_vertex(Vector3(x,0.028,0));mesh.surface_add_vertex(Vector3(x,0.028,h))
	for y in range(int(h)+1):mesh.surface_add_vertex(Vector3(0,0.028,y));mesh.surface_add_vertex(Vector3(w,0.028,y))
	mesh.surface_end();var instance=MeshInstance3D.new();instance.mesh=mesh
	var material=mat(Color(0.87,0.91,0.95,0.22));instance.material_override=material;terrain.add_child(instance)

func build_tree(pos: Vector3,v: float):
	cylinder(terrain,pos+Vector3(0,0.38,0),0.10,0.76,Color("65503c"))
	var color=Color("3e6552").lightened(v*0.08)
	for i in 3:cylinder(terrain,pos+Vector3(0,0.8+i*0.37,0),0.57-i*0.1,0.82,color.lightened(i*0.04),0.035)

func build_torch(pos: Vector3):
	cylinder(terrain,pos+Vector3(0,0.15,0),0.16,0.3,Color("3a3733"))
	var glow=sphere(terrain,pos+Vector3(0,0.38,0),0.105,Color("ffd291"));glow.material_override=mat(Color("ffc276"),0,2.5)
	pass # Torch light is managed by the capped scene lighting pool.

func find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var found=find_anim(child)
		if found:return found
	return null

func create_mini(a: Dictionary) -> Node3D:
	var root=Node3D.new();minis.add_child(root)
	var size_mini=float(a.get("token_size",1));root.position=Vector3(a.x+size_mini/2,0.055+floor_y(a),a.y+size_mini/2)
	root.set_meta("logical_cell",Vector2i(a.x,a.y));root.set_meta("waypoints",[])
	var color=Color(a.color);var radius=size_mini*0.40
	cylinder(root,Vector3(0,0.045,0),radius,0.09,Color("161d29"))
	cylinder(root,Vector3(0,0.095,0),radius*0.95,0.025,color)
	var selection=MeshInstance3D.new();selection.name="Selection";var torus=TorusMesh.new();torus.inner_radius=radius+0.035;torus.outer_radius=radius+0.075;torus.rings=24;torus.ring_segments=8;selection.mesh=torus;selection.material_override=mat(BLUE,0,0.5);selection.position.y=0.05;root.add_child(selection)
	var figure=Node3D.new();figure.name="Figure";root.add_child(figure);figure.position.y=0.10;figure.scale=Vector3.ONE*(5.0/maxf(0.1,World.encounter.feet_per_cell()))
	var kind=str(a.get("miniature","Auto"))
	if kind=="Auto":kind="Adventurer" if a.hero else "Skeleton" if a.race.to_lower().contains("undead") else "Dragon" if a.race.to_lower().contains("dragon") else "Beast" if a.race.to_lower().contains("beast") else "Orc"
	var scale_figure=minf(size_mini,2.4)
	if kind=="Adventurer":build_adventurer(figure,a,scale_figure)
	elif kind=="Orc":
		var body=model(figure,"character-orc",Vector3.ZERO,Vector3.ONE*1.28*scale_figure,-0.3)
		var anim=find_anim(body)
		if anim and anim.has_animation("idle"):anim.get_animation("idle").loop_mode=Animation.LOOP_LINEAR;anim.play("idle")
		model(figure,"weapon-sword",Vector3(0.32,0.45,0.10),Vector3.ONE*scale_figure)
	elif kind=="Skeleton":build_skeleton(figure,color)
	elif kind=="Dragon":build_dragon(figure,color,scale_figure)
	else:build_beast(figure,color,scale_figure)
	if a.hp<=0:figure.rotation_degrees.z=82;figure.position.y=0.18
	var animator=find_anim(root)
	if animator:
		root.set_meta("animator",animator);root.set_meta("idle_anim",animator.current_animation)
		for anim_name in animator.get_animation_list():
			if str(anim_name).to_lower().contains("walk") and not str(anim_name).to_lower().contains("back"):root.set_meta("walk_anim",str(anim_name));animator.get_animation(anim_name).loop_mode=Animation.LOOP_LINEAR;break
	return root

func build_skeleton(parent: Node3D,color: Color):
	var bone=Color("dbd3bb");sphere(parent,Vector3(0,0.85,0),0.17,bone)
	for x in [-0.2,0.2]:cylinder(parent,Vector3(x,0.28,0),0.04,0.45,bone)
	box(parent,Vector3(0,0.55,0),Vector3(0.36,0.09,0.15),bone)
	cylinder(parent,Vector3(0,0.66,0),0.045,0.28,bone)
	for y in [0.57,0.65,0.73]:box(parent,Vector3(0,y,0),Vector3(0.30,0.025,0.13),bone)
	for x in [-0.25,0.25]:cylinder(parent,Vector3(x,0.62,0),0.035,0.35,bone)
	for x in [-0.07,0.07]:sphere(parent,Vector3(x,0.89,0.145),0.037,Color("222936"))
	model(parent,"weapon-sword",Vector3(0.30,0.46,0.08),Vector3.ONE)

func build_beast(parent: Node3D,color: Color,factor: float):
	var shape=Node3D.new();parent.add_child(shape);shape.scale=Vector3.ONE*factor
	var torso=sphere(shape,Vector3(0,0.4,0),0.29,color);torso.scale=Vector3(0.7,0.85,1.4)
	sphere(shape,Vector3(0,0.57,0.33),0.18,color.lightened(0.13))
	for x in [-0.14,0.14]:
		for z in [-0.23,0.23]:cylinder(shape,Vector3(x,0.20,z),0.045,0.32,color.darkened(0.2))
	for x in [-0.10,0.10]:cylinder(shape,Vector3(x,0.77,0.30),0.08,0.24,color,0)

func build_dragon(parent: Node3D,color: Color,factor: float):
	build_beast(parent,color,factor)
	for side in [-1,1]:
		var wing=box(parent,Vector3(side*0.38*factor,0.62*factor,-0.10),Vector3(0.55*factor,0.035,0.5*factor),color.darkened(0.18));wing.rotation_degrees=Vector3(10,side*20,side*28)
	cylinder(parent,Vector3(0,0.22,-0.55*factor),0.12*factor,0.9*factor,color,0).rotation_degrees.x=75

func draw_overlay():
	if zones_controller!=null:zones_controller.draw()
	if build_controller!=null:build_controller.draw_preview()
	if camera==null or World.data.is_empty():return
	var s=World.scene();var pixels=Vector2(0,size.y/extent).length()
	if coordinates and pixels>16 and not immersive():
		for x in int(s.width):draw_text(project(Vector3(x+0.5,0,-0.34)),Rules5e.column_name(x),12,Color("a9b7c8"),true)
		for y in int(s.height):draw_text(project(Vector3(-0.35,0,y+0.5)),str(y+1),12,Color("a9b7c8"),true)
	if immersive():draw_immersive_overlay();return
	for area in s.get("areas",[]):draw_area(area)
	if area_start.x>=0:draw_area({"x":area_start.x,"y":area_start.y,"ex":hover.x,"ey":hover.y,"shape":tool})
	if valid_cell(hover) and tool in ["Paint","Reveal","Conceal"]:draw_cell(hover,Color(0.5,0.72,1,0.22),BLUE)
	if drag_id!="":
		var a=World.actor(drag_id)
		if not a.is_empty():draw_ruler(Vector2i(a.x,a.y),drag_cell,true)
	if ruler_start.x>=0:draw_ruler(ruler_start,hover,false)
	if drag_id=="" and not attack_preview.is_empty() and attack_preview.get("attacker","")==World.selected:
		var info=attack_preview;var from=project(Vector3(info.from.x+0.5,0.14,info.from.y+0.5));var to=project(Vector3(info.to.x+0.5,0.14,info.to.y+0.5))
		var color=Color("8bd7b4") if info.ok else Color("ee929d")
		overlay.draw_line(from,to,Color("101824"),4,true);overlay.draw_dashed_line(from,to,color,1.5,9,true)
		var caption="In range" if info.ok else "Out of range" if str(info.reason).begins_with("Out of range") else "Blocked"
		draw_text((from+to)/2+Vector2(0,-12),World.COMBAT.distance_text(float(info.distance))+" ft · "+caption,12,color,true)
	for a in World.data.actors:
		if not actors.has(a.id):continue
		var node=actors[a.id];var footprint=float(a.get("token_size",1))
		var point=project(node.position+Vector3(0,1.3*minf(footprint,2.4),0))
		if point.x<0 or point.y<0 or point.x>size.x or point.y>size.y:continue
		if labels or a.id==World.selected:
			var title=str(a.name).split(" ")[0];var c=Color(a.color).lightened(0.18)
			draw_text(point,title,13,c,true)
			var rect=Rect2(point+Vector2(-23,7),Vector2(46,4));overlay.draw_style_box(flat(Color("111827")),rect);overlay.draw_rect(Rect2(rect.position,Vector2(46*clampf(float(a.hp)/maxf(a.max_hp,1),0,1),4)),Color("84d3b5") if a.hp>0 else Color("d2828e"))
		if not a.conditions.is_empty():draw_text(point+Vector2(0,-20),"● "+str(a.conditions[0]),11,Color("edc581"),true)
	if World.ping_time>0:
		var p=project(Vector3(World.ping_cell.x+0.5,0.08,World.ping_cell.y+0.5));overlay.draw_arc(p,16+fmod(elapsed*30,28),0,TAU,48,BLUE,2,true)
	# Always-visible scale bar and scene units, rendered at native screen resolution.
	var units=World.grid_settings();var scale_squares=4.0
	var per_square=project(target+camera.global_basis.x).distance_to(project(target))
	while per_square*scale_squares>200 and scale_squares>0.5:scale_squares/=2
	while per_square*scale_squares<60 and scale_squares<32:scale_squares*=2
	var line_width=per_square*scale_squares
	var p=Vector2(22,size.y-42);overlay.draw_line(p,p+Vector2(line_width,0),Color("dae4f1"),2,true);overlay.draw_line(p-Vector2(0,4),p+Vector2(0,4),Color("dae4f1"),2);overlay.draw_line(p+Vector2(line_width,-4),p+Vector2(line_width,4),Color("dae4f1"),2)
	draw_text(p+Vector2(line_width/2,-12),World.format_distance(units.distance*scale_squares),12,Color("e6edf7"),true)
	draw_text(Vector2(22,size.y-15),"1 square = "+World.format_distance(units.distance)+"   ·   "+str(s.width)+" × "+str(s.height)+" squares   ·   "+str(int(round(zoom*100)))+"%",12,Color("bac8d9"))
	var compass=Vector2(size.x-38,42)
	var north=(project(target+Vector3(0,0,-1))-project(target)).normalized()
	overlay.draw_arc(compass,16,0,TAU,32,Color(0.65,0.75,0.9,0.3),1,true)
	overlay.draw_line(compass-north*10,compass+north*12,BLUE,2,true)
	draw_text(compass+north*27+Vector2(0,4),"N",12,Color("bac8d9"),true)

func flat(color: Color) -> StyleBoxFlat:
	var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(3);return b

func draw_text(pos: Vector2,text: String,font_size: int,color: Color,center: bool=false):
	var text_size=regular.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var origin=pos-Vector2(text_size.x/2,0) if center else pos
	overlay.draw_style_box(flat(Color(0.035,0.055,0.09,0.85*color.a)),Rect2(origin+Vector2(-5,-font_size-2),text_size+Vector2(10,5)))
	overlay.draw_string(regular,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func draw_cell(cell: Vector2i,color: Color,edge: Color):
	var points=PackedVector2Array()
	for p in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:points.append(project(Vector3(cell.x+p.x,0.045,cell.y+p.y)))
	overlay.draw_colored_polygon(points,color);points.append(points[0]);overlay.draw_polyline(points,edge,1.5,true)

func draw_ruler(start: Vector2i,end: Vector2i,moving: bool):
	var from=project(Vector3(start.x+0.5,0.1,start.y+0.5));var to=project(Vector3(end.x+0.5,0.1,end.y+0.5))
	overlay.draw_line(from,to,Color("101824"),5,true);overlay.draw_line(from,to,BLUE,2,true);overlay.draw_circle(from,4,BLUE);overlay.draw_circle(to,5,BLUE)
	var count=maxi(absi(start.x-end.x),absi(start.y-end.y))
	for i in range(count+1):
		var cell=Vector2i(Vector2(start).lerp(Vector2(end),float(i)/maxf(1,count)).round());draw_cell(cell,Color(0.35,0.6,1,0.12),Color(0.5,0.7,1,0.3))
	var text=World.format_distance(World.measure_cells(start,end))+" · "+str(count)+" squares"
	if moving:text+=" · move"
	draw_text((from+to)/2+Vector2(0,-14),text,15,Color("e2edff"),true)

func draw_area(area: Dictionary):
	var origin=Vector3(float(area.x)+0.5,0.06,float(area.y)+0.5);var end=Vector3(float(area.ex)+0.5,0.06,float(area.ey)+0.5)
	var radius=maxf(0.5,origin.distance_to(end));var points=PackedVector2Array()
	if area.shape=="Circle":
		for i in 65:points.append(project(origin+Vector3(cos(i*TAU/64),0,sin(i*TAU/64))*radius))
	elif area.shape=="Cone":
		var direction=(end-origin).normalized();var across=Vector3(-direction.z,0,direction.x)*radius/2
		for p in [origin,end+across,end-across,origin]:points.append(project(p))
	else:
		for p in [origin,Vector3(end.x,0.06,origin.z),end,Vector3(origin.x,0.06,end.z),origin]:points.append(project(p))
	if points.size()>3:
		overlay.draw_colored_polygon(points,Color(0.46,0.65,1,0.13));overlay.draw_polyline(points,Color(0.6,0.77,1,0.75),1.5,true)

func build_adventurer(parent: Node3D,a: Dictionary,factor: float):
	var archetype="Mage" if a.class in ["Wizard","Sorcerer","Warlock","Druid","Bard"] else "Rogue_Hooded" if a.class in ["Rogue","Ranger","Monk"] else "Barbarian" if a.class=="Barbarian" else "Knight"
	var body=model(parent,"kk-"+archetype,Vector3.ZERO,Vector3.ONE*0.54*factor,-0.25)
	configure_adventurer(body,archetype,a.class)
	var anim=find_anim(body)
	var animation="2H_Melee_Idle" if archetype in ["Mage","Barbarian"] else "Idle"
	if anim and anim.has_animation(animation):anim.get_animation(animation).loop_mode=Animation.LOOP_LINEAR;anim.play(animation)

func configure_adventurer(node: Node,archetype: String,hero_class: String):
	if node is MeshInstance3D:
		var title=str(node.name)
		var prefix="Rogue" if archetype=="Rogue_Hooded" else archetype
		var allowed={"Knight":["1H_Sword","Round_Shield"],"Mage":["2H_Staff"],"Rogue_Hooded":["Knife","Knife_Offhand"],"Barbarian":["2H_Axe"]}
		node.visible=title.begins_with(prefix+"_") or title in allowed[archetype]
		if hero_class=="Cleric" and title=="Knight_Helmet":node.visible=false
	for child in node.get_children():configure_adventurer(child,archetype,hero_class)

func pick_actor(pos: Vector2) -> Dictionary:
	var pixel=pos*Vector2(viewport.size)/Vector2(maxf(1,size.x),maxf(1,size.y));var origin=camera.project_ray_origin(pixel);var direction=camera.project_ray_normal(pixel)
	var nearest=INF;var result={};var viewer=pov_actor()
	for a in World.data.actors:
		if a.id==pov_actor_id or not actors.has(a.id) or not World.visible(a):continue
		var size_mini=float(a.get("token_size",1));var bounds=AABB(Vector3(a.x+0.1,floor_y(a),a.y+0.1),Vector3(size_mini-0.2,1.5*minf(size_mini,2.4),size_mini-0.2))
		var hit=bounds.intersects_ray(origin,direction)
		if hit==null or origin.distance_to(hit)>=nearest:continue
		if camera_mode!="Tactical" and not viewer.is_empty() and is_inf(World.COMBAT.clear_distance(viewer,a,World.scene()).distance):continue
		result=a;nearest=origin.distance_to(hit)
	return result
func immersive_input(event):
	if event is InputEventMouseMotion:
		if rotating:pov_yaw-=event.relative.x*0.005;look_pitch=clampf(look_pitch-event.relative.y*0.004,-1.05,0.9);update_camera()
		var actor=pick_actor(event.position)
		map_hint.emit(actor.name+" · click to target" if not actor.is_empty() else "WASD move · Hold right mouse to look · E opens a nearby door · Tab changes camera")
	if not event is InputEventMouseButton:return
	grab_focus()
	if event.button_index==MOUSE_BUTTON_RIGHT:rotating=event.pressed;return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		if camera_mode=="Following":follow_distance=clampf(follow_distance+(0.5 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -0.5),1.8,9)
		else:pov_fov=clampf(pov_fov+(3 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -3),50,90)
		return
	if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var actor=pick_actor(event.position)
		if not actor.is_empty():target_id=actor.id;target_selected.emit(actor.id);return
		var cell=cell_at(event.position)
		if valid_cell(cell):ground_selected.emit(cell)
func _unhandled_key_input(event):
	if not immersive() or input_locked or not event is InputEventKey or not event.pressed:return
	var focus=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:return
	var a=pov_actor()
	if a.is_empty():return
	if camera_mode=="Tactical":
		if event.keycode==KEY_E:
			for dx in range(-1,int(a.get("token_size",1))+1):
				for dy in range(-1,int(a.get("token_size",1))+1):
					var cell=Vector2i(a.x+dx,a.y+dy)
					if int(World.scene().tiles.get(World.cell_key(cell.x,cell.y),0))==6:World.command("door",{"id":a.id,"x":cell.x,"y":cell.y});get_viewport().set_input_as_handled();return
		elif event.keycode in [KEY_HOME,KEY_C]:focus_selected()
		elif event.keycode==KEY_O:tactical_top=not tactical_top;update_camera()
		elif event.keycode==KEY_ESCAPE:tactical_cancelled.emit()
		else:return
		get_viewport().set_input_as_handled();return
	if event.keycode==KEY_TAB:set_view("Following" if camera_mode=="First person" else "First person");get_viewport().set_input_as_handled();return
	if event.keycode==KEY_E:
		for dx in range(-1,2):
			for dy in range(-1,2):
				var cell=Vector2i(a.x+dx,a.y+dy)
				if int(World.scene().tiles.get(World.cell_key(cell.x,cell.y),0))==6:World.command("door",{"id":a.id,"x":cell.x,"y":cell.y});get_viewport().set_input_as_handled();return
	if event.keycode not in [KEY_W,KEY_A,KEY_S,KEY_D] or move_cooldown>0:return
	var forward=Vector2(-sin(pov_yaw),-cos(pov_yaw));var right=Vector2(cos(pov_yaw),-sin(pov_yaw))
	var vector=forward if event.keycode==KEY_W else -forward if event.keycode==KEY_S else -right if event.keycode==KEY_A else right
	var step=Vector2i(round(vector.x),round(vector.y))
	World.command("move",{"id":a.id,"x":int(a.x)+step.x,"y":int(a.y)+step.y});move_cooldown=0.15;get_viewport().set_input_as_handled()
func draw_immersive_overlay():
	var viewer=pov_actor()
	if viewer.is_empty():draw_text(Vector2(25,45),"Waiting for the DM to assign your hero.",18,BLUE);return
	var center=size/2
	if camera_mode!="Tactical":
		overlay.draw_line(center-Vector2(6,0),center+Vector2(6,0),Color(0.9,0.94,1,0.55),1,true);overlay.draw_line(center-Vector2(0,6),center+Vector2(0,6),Color(0.9,0.94,1,0.55),1,true)
	else:draw_movement_preview()
	draw_text(Vector2(22,32),viewer.name+" · "+camera_mode,14,BLUE)

	for a in World.data.actors:
		if (a.id==viewer.id and camera_mode!="Tactical") or not actors.has(a.id):continue
		var point=actors[a.id].position+Vector3.UP*1.45*minf(float(a.get("token_size",1)),2.4)
		if camera.is_position_behind(point) or (camera_mode!="Tactical" and is_inf(World.COMBAT.clear_distance(viewer,a,World.scene()).distance)):continue
		var screen=project(point)
		if not Rect2(Vector2.ZERO,size).has_point(screen):continue
		var distance=World.COMBAT.distance(viewer,a,World.scene())
		draw_text(screen,a.name+" · "+World.COMBAT.distance_text(distance)+" ft",13,Color("edba9e") if World.COMBAT.hostile(viewer,a) else BLUE,true)
		if a.id==target_id:draw_text(screen+Vector2(0,-22),"◆ TARGET",12,Color("ffcf75"),true)
	for event in float_events:
		var a=World.actor(str(event.get("target","")))
		var world=Vector3(float(event.x)+0.5,(floor_y(a) if not a.is_empty() else 0)+(1.7 if event.kind=="attack" else 1.95 if event.kind=="save" else 1.4)+float(event.age)*0.18,float(event.y)+0.5)
		if camera.is_position_behind(world):continue
		var color=Color("80d1b8") if event.kind=="heal" else Color("ffc6ad") if event.kind=="damage" else Color("f1dca7")
		color.a=clampf((2.6-float(event.age))/0.8,0,1)
		draw_text(project(world),str(event.title) if event.kind in ["damage","heal"] else str(event.text).split(" · ")[0],19,color,true)
	if not attack_preview.is_empty():
		var a=World.actor(str(attack_preview.get("target","")))
		if not a.is_empty() and actors.has(a.id):
			var point=actors[a.id].position+Vector3.UP*0.7
			if not camera.is_position_behind(point):draw_text(project(point),"IN RANGE" if attack_preview.ok else "OUT OF RANGE" if str(attack_preview.reason).begins_with("Out of range") else "ACTION SPENT" if str(attack_preview.reason).begins_with("Action spent") else "WAIT FOR TURN" if str(attack_preview.reason).contains("turn") else "BLOCKED",14,Color("80d1b8") if attack_preview.ok else Color("ee929d"),true)

func draw_spell_preview():
	var info=spell_preview;var center=Vector3(info.origin.x+0.5,World.encounter.elevation(info.origin)/World.encounter.feet_per_cell()+0.08,info.origin.y+0.5)
	var points=PackedVector2Array()
	if info.shape in ["sphere","cylinder"]:
		for n in 65:
			var point=center+Vector3(cos(n*TAU/64),0,sin(n*TAU/64))*float(info.size)
			if camera.is_position_behind(point):return
			points.append(project(point))
	else:
		var from=Vector3(info.caster.x+0.5,center.y,info.caster.y+0.5);var direction=(center-from).normalized()
		if direction.is_zero_approx():direction=Vector3.FORWARD
		var end=from+direction*float(info.size);var across=Vector3(-direction.z,0,direction.x)
		var spread=float(info.size)/2 if info.shape=="cone" else 0.5
		for point in [from,end+across*spread,end-across*spread,from]:
			if camera.is_position_behind(point):return
			points.append(project(point))
	if points.size()>2:overlay.draw_colored_polygon(points,Color(0.9,0.42,0.2,0.13));overlay.draw_polyline(points,Color("f3b679"),2,true)

func build_spell_preview():
	clear_node(preview_root)
	if spell_preview.is_empty():return
	var info=spell_preview;var center=Vector3(info.origin.x+0.5,World.encounter.elevation(info.origin)/World.encounter.feet_per_cell()+0.045,info.origin.y+0.5)
	var vertices=[];var radius=float(info.size)
	if info.shape in ["sphere","cylinder"]:
		for n in 65:vertices.append(center+Vector3(cos(n*TAU/64),0,sin(n*TAU/64))*radius)
	elif info.shape=="cube":
		for delta in [Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1),Vector3(-1,0,-1)]:vertices.append(center+delta*radius/2)
	else:
		var origin=Vector3(info.caster.x+0.5,center.y,info.caster.y+0.5);var direction=(center-origin).normalized()
		if direction.is_zero_approx():direction=Vector3.FORWARD
		var across=Vector3(-direction.z,0,direction.x);var end=origin+direction*radius;var width=radius/2 if info.shape=="cone" else 0.5
		vertices=[origin,end+across*width,end-across*width,origin]
	if vertices.size()<3:return
	var fill=ImmediateMesh.new();fill.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(1,vertices.size()-1):fill.surface_add_vertex(center);fill.surface_add_vertex(vertices[n]);fill.surface_add_vertex(vertices[n+1])
	fill.surface_end();var area=MeshInstance3D.new();area.mesh=fill;area.material_override=mat(Color(0.95,0.4,0.12,0.18),0,0.1);preview_root.add_child(area)
	var line=ImmediateMesh.new();line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for vertex in vertices:line.surface_add_vertex(vertex+Vector3.UP*0.01)
	line.surface_end();var edge=MeshInstance3D.new();edge.mesh=line;edge.material_override=mat(Color("f3bb7d"),0,0.8);preview_root.add_child(edge)
func play_attack(event: Dictionary):
	var attacker=actors.get(str(event.get("actor","")));var target=actors.get(str(event.get("target","")))
	if attacker==null or target==null:return
	var animator=attacker.get_meta("animator") if attacker.has_meta("animator") else null
	if animator:
		for name_animation in animator.get_animation_list():
			if str(name_animation).to_lower().contains("attack") or str(name_animation).to_lower().contains("spellcast"):
				animator.play(name_animation,0.08);attacker.set_meta("attacking_until",elapsed+0.7);break
	var from=attacker.position+Vector3.UP*0.7;var to=target.position+Vector3.UP*0.7
	var color=Color("91bcff") if World.spell_lookup.has(World.COMBAT.key(str(event.title))) else Color("f7cb8b")
	var orb=sphere(stage,from,0.055,color);orb.material_override=mat(color,0,1.4)
	var tween=create_tween();tween.tween_property(orb,"position",to,0.3);tween.tween_property(orb,"scale",Vector3.ONE*2.4,0.08);tween.tween_callback(orb.queue_free)

func elevated_image(position: Vector3,s: Dictionary):
	if floor_texture==null:return
	if patch_material==null:
		var shader=Shader.new();shader.code="shader_type spatial; varying vec2 map_pos; uniform sampler2D image_tex : source_color, filter_linear_mipmap_anisotropic; uniform sampler2D glow_mask : filter_nearest; uniform vec2 image_size; uniform vec2 board_size; uniform vec2 offset_px; uniform float pixels; void vertex(){map_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;} void fragment(){vec2 uv=pixels>0.0?(map_pos*pixels+offset_px)/image_size:map_pos/board_size; ALBEDO=texture(image_tex,uv).rgb;ROUGHNESS=1.0;}"
		patch_material=ShaderMaterial.new();patch_material.shader=shader;patch_material.set_shader_parameter("image_tex",floor_texture);patch_material.set_shader_parameter("image_size",Vector2(floor_texture.get_size()));patch_material.set_shader_parameter("board_size",Vector2(s.width,s.height));patch_material.set_shader_parameter("offset_px",Vector2(s.get("grid_offset_x",0),s.get("grid_offset_y",0)));patch_material.set_shader_parameter("pixels",float(s.get("grid_pixels",0)))
	var mesh=PlaneMesh.new();mesh.size=Vector2.ONE;var top=MeshInstance3D.new();top.mesh=mesh;top.material_override=patch_material;top.position=position+Vector3.UP*0.004;terrain.add_child(top)

# Tactical player navigation. Camera motion never mutates actor state.
func process_tactical(delta: float):
	var a=pov_actor()
	if a.is_empty():return
	var center=actors[a.id].position if actors.has(a.id) else Vector3(a.x+0.5,floor_y(a),a.y+0.5)
	if tactical_tracking:tactical_focus=tactical_focus.lerp(center,1.0-exp(-delta*9.0))
	var focus=get_viewport().gui_get_focus_owner()
	if not input_locked and not (focus is LineEdit or focus is TextEdit or focus is SpinBox) and not Input.is_key_pressed(KEY_CTRL):
		var axis=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if axis.length()>0.01:pan_tactical(axis.normalized()*delta*tactical_distance*0.6)
		var door_near=false
		for dx in range(-1,int(a.get("token_size",1))+1):
			for dy in range(-1,int(a.get("token_size",1))+1):
				if int(World.scene().tiles.get(World.cell_key(a.x+dx,a.y+dy),0))==6:door_near=true
		var orbit=float(Input.is_physical_key_pressed(KEY_Q))-float(Input.is_physical_key_pressed(KEY_E) and not door_near)
		tactical_yaw+=orbit*delta*1.5
	update_camera();route_tick-=delta
	if route_tick<=0:
		route_tick=0.09
		var local=get_local_mouse_position()
		var gui=get_viewport().gui_get_hovered_control()
		var world_hover=gui==self or gui==null
		if Rect2(Vector2.ZERO,size).has_point(local) and world_hover and not input_locked and not rotating and not panning:
			hover=cell_at(local);var unit=pick_actor(local);var id=str(unit.get("id",""))
			if id!=hover_actor_id:hover_actor_id=id;tactical_hovered.emit(id)
			update_movement_preview(hover)
		else:movement_preview={}

func pan_tactical(axis: Vector2):
	var right=Vector3(cos(tactical_yaw),0,-sin(tactical_yaw))
	var backward=Vector3(sin(tactical_yaw),0,cos(tactical_yaw))
	tactical_focus+=right*axis.x+backward*axis.y;tactical_tracking=false
	tactical_focus.x=clampf(tactical_focus.x,0,float(World.scene().width));tactical_focus.z=clampf(tactical_focus.z,0,float(World.scene().height))

func update_movement_preview(cell: Vector2i):
	var a=pov_actor()
	if a.is_empty() or targeting or not valid_cell(cell) or not World.cell_visible(cell) or not hover_actor_id.is_empty():movement_preview={};return
	var signature=str([a.id,a.x,a.y,a.get("moved",0),a.get("dash_ft",0),a.conditions,cell,World.data.combat,World.scene().tiles.hash(),World.scene().get("elevations",{}).hash(),World.scene().get("doors_open",{}).hash(),World.data.actors.hash()])
	if signature==movement_signature and not movement_preview.is_empty():return
	movement_signature=signature;movement_preview=World.encounter.movement(a,cell,true);movement_preview.destination=cell
	map_hint.emit(str(movement_preview.reason)+" · "+World.COMBAT.distance_text(float(movement_preview.cost))+" ft" if not movement_preview.path.is_empty() else str(movement_preview.reason))

func tactical_input(event):
	if event is InputEventMouseMotion:
		if rotating:tactical_yaw-=event.relative.x*0.007;tactical_pitch=clampf(tactical_pitch+event.relative.y*0.004,0.48,1.36);tactical_top=false;update_camera()
		elif panning:pan_tactical(Vector2(-event.relative.x,-event.relative.y)*tactical_distance/size.y);update_camera()
		return
	if not event is InputEventMouseButton:return
	grab_focus()
	if event.button_index==MOUSE_BUTTON_MIDDLE or (event.button_index==MOUSE_BUTTON_LEFT and (event.shift_pressed or rotating)):
		rotating=event.pressed;rotation_button=event.button_index;return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed:tactical_cancelled.emit();movement_signature=""
		return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		tactical_distance=clampf(tactical_distance*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else 1.0/1.12),4.5,25);update_camera();return
	if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var unit=pick_actor(event.position)
		if not unit.is_empty():target_id=unit.id;target_selected.emit(unit.id);return
		var cell=cell_at(event.position)
		if valid_cell(cell) and World.cell_visible(cell):ground_selected.emit(cell)

func draw_movement_preview():
	if movement_preview.is_empty() or targeting or input_locked:return
	var a=pov_actor()
	if a.is_empty():return
	var from=Vector3(a.x+0.5,floor_y(a)+0.10,a.y+0.5);var remaining=maxf(0,World.encounter.speed(a)+float(a.get("dash_ft",0))-float(a.get("moved",0)))
	var used=0.0;var previous=Vector2i(a.x,a.y)
	for point in movement_preview.path:
		var cell=Vector2i(point.x,point.y);var to=Vector3(point.x+0.5,World.encounter.elevation(cell)/World.encounter.feet_per_cell()+0.10,point.y+0.5)
		used+=World.movement_feet(previous,cell)*(2 if int(World.scene().tiles.get(World.cell_key(cell.x,cell.y),0)) in [4,12] or a.conditions.has("Prone") else 1)
		var color=Color("ead9a3") if movement_preview.ok else Color("e69683")
		if not camera.is_position_behind(from) and not camera.is_position_behind(to):overlay.draw_line(project(from),project(to),color,3,true);overlay.draw_circle(project(to),3,color,true,-1,true)
		from=to;previous=cell
	if movement_preview.path.is_empty():return
	if camera.is_position_behind(from):return
	var p=project(from);var color=Color("b8dab3") if movement_preview.ok else Color("f1a493")
	overlay.draw_arc(p,11,0,TAU,32,color,2,true)
	var message=World.COMBAT.distance_text(float(movement_preview.cost))+" ft"
	if World.data.combat.active:message+=" · "+World.COMBAT.distance_text(maxf(0,remaining-float(movement_preview.cost)))+" ft left" if movement_preview.ok else " · Not enough movement" if str(movement_preview.reason).begins_with("Not enough") else " · "+str(movement_preview.reason)
	draw_text(p+Vector2(0,-22),message,14,color,true)
