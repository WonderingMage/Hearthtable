extends RefCounted
const B=preload("res://scripts/build_system.gd")
const M=preload("res://scripts/build_models.gd")
var u
var w
var root: VBoxContainer
var active=false
var asset="stone"
var category="Floors & terrain"
var query=""
var mode="Area"
var rotation=0
var swatch=0
var move_uid=""
var start=Vector2i(-1,-1)
var hover=Vector2i(-1,-1)
var ghost: Node3D
var thumb_root: Node
var thumbnails={}
var catalog_list: HBoxContainer
var info: Label
var step=5.0
func _init(app,world):u=app;w=world;B.ensure()
func create(parent: Node):
	root=u.panel(parent);root.get_parent().name="BuildCatalog";root.get_parent().visible=false;u.expand(root.get_parent());root.add_theme_constant_override("separation",6)
	thumb_root=Node.new();u.add_child(thumb_root);u.board.build_controller=self
func toggle():
	if w.client:return
	active=not active
	if active and u.battle_ui!=null:u.battle_ui.enemy_mode=false;u.battle_ui.refresh();u.zones_ui.cancel()
	u.board.tool="Build" if active else "Select"
	if not active:cancel();u.set_tool("Select")
	else:
		w.preview=false;u.board.dirty=true;u.refresh();var d=B.definition(asset);mode="Area" if d.kind=="surface" else "Line" if d.kind=="wall" else "Place"
	root.get_parent().visible=active;u.apply_view_layout();refresh()
func cancel():
	if not move_uid.is_empty():
		var old=u.board.terrain.get_node_or_null("Prop_"+move_uid)
		if old:old.show()
	move_uid="";start=Vector2i(-1,-1)
	if is_instance_valid(ghost):ghost.queue_free();ghost=null
func choose(id: String):
	cancel();asset=id;rotation=0;var d=B.definition(id);mode="Area" if d.kind=="surface" else "Line" if d.kind=="wall" else "Place";refresh()
func refresh():
	root.get_parent().visible=active and not w.client
	if not active or w.client:return
	u.clear(root)
	var top=u.row(root);top.add_child(u.label("BUILD CATALOG",12,u.GOLD))
	var categories=[]
	for d in B.catalog.values():
		if not categories.has(d.category):categories.append(d.category)
	var filter=u.options(top,categories,maxi(0,categories.find(category)));filter.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;filter.item_selected.connect(func(i):category=categories[i];populate())
	var search=u.line(top,"Find a throne, lava, bridge…",query);search.custom_minimum_size.x=180;search.text_changed.connect(func(value):query=value;populate())
	u.button(top,"New themed scene…",templates);u.button(top,"Undo",func():w.undo(),"Ctrl+Z · One build operation per undo")
	u.button(top,"Exit build · F2",toggle,"Return to DM creature controls",true)
	var controls=u.row(root);var d=B.definition(asset)
	for item in (["Area","Single","Fill"] if d.kind=="surface" else ["Line","Room"] if d.kind=="wall" else ["Place"]):
		u.button(controls,item,func():cancel();mode=item;refresh()).add_theme_color_override("font_color",u.GOLD if mode==item else u.MUTED)
	for item in ["Move","Duplicate","Eyedropper","Delete","Raise","Lower"]:u.button(controls,item,func():cancel();mode=item;refresh()).add_theme_color_override("font_color",u.GOLD if mode==item else u.MUTED)
	u.button(controls,"Rotate · R",func():rotation=(rotation+1)%4;update_ghost())
	var colors=u.options(controls,["Original","Obsidian","Ivory","Royal blue"],swatch);colors.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;colors.item_selected.connect(func(i):swatch=i;update_ghost())
	controls.add_child(u.label("Height ft",10,u.MUTED))
	var height=u.number(controls,int(step),1,20);height.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;height.custom_minimum_size.x=65;height.tooltip_text="Raise/lower step in feet";height.value_changed.connect(func(v):step=v)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size.y=121;root.add_child(scroll);catalog_list=u.row(scroll);populate()
	info=u.label(d.name+" · "+str(d.w)+" × "+str(d.h)+" squares · "+mode+" · Shift-drag orbits · R rotates · Esc cancels",11,u.GOLD);info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;root.add_child(info)
func thumbnail(d: Dictionary) -> Texture2D:
	if thumbnails.has(d.id):return thumbnails[d.id]
	var viewport=SubViewport.new();viewport.size=Vector2i(96,76);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;thumb_root.add_child(viewport)
	var stage=Node3D.new();viewport.add_child(stage);var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.65;stage.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.2;stage.add_child(sun)
	var model=M.make(d);stage.add_child(model)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(1.6,maxf(float(d.w),float(d.h))*1.3);stage.add_child(camera);camera.position=Vector3(3.8,3.1,4.2);camera.look_at(Vector3(0,float(d.height)*.4,0));camera.current=true
	thumbnails[d.id]=viewport.get_texture();return thumbnails[d.id]
func populate():
	if not is_instance_valid(catalog_list):return
	u.clear(catalog_list)
	for d in B.catalog.values():
		if not query.is_empty():
			if not (d.name+" "+d.category).to_lower().contains(query.to_lower()):continue
		elif d.category!=category:continue
		var button=Button.new();catalog_list.add_child(button);button.custom_minimum_size=Vector2(108,116);button.tooltip_text=d.name+" · "+str(d.w)+" × "+str(d.h)+" squares"+(" · Blocks walking" if d.solid else " · Walkable/decorative")+"\n"+str(d.hazard);button.pressed.connect(func():choose(d.id))
		button.add_theme_stylebox_override("normal",u.gilded("selected" if asset==d.id else "button",5))
		var box=VBoxContainer.new();button.add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.offset_left=5;box.offset_right=-5;box.offset_top=5;box.offset_bottom=-5;box.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var picture=TextureRect.new();picture.texture=thumbnail(d);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size=Vector2(96,76);picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(picture)
		var label=u.label(d.name,11,u.INK);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(label)
func update_ghost():
	if is_instance_valid(ghost):ghost.queue_free();ghost=null
	if not active or hover.x<0 or mode not in ["Place","Area","Single","Line","Room"]:return
	var d=B.definition(asset)
	if d.kind!="prop":return
	ghost=M.make(d,swatch);u.board.stage.add_child(ghost);var footprint=B.footprint(d,rotation);ghost.position=Vector3(hover.x+footprint.x/2.0,w.encounter.elevation(hover)/w.encounter.feet_per_cell(),hover.y+footprint.y/2.0);ghost.rotation.y=rotation*PI/2
	var valid=w.builder.assessment(asset,hover,rotation,move_uid);var m=StandardMaterial3D.new();m.albedo_color=Color(.5,1,.7,.48) if valid.ok else Color(1,.35,.3,.5);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material(ghost,m)
func ghost_material(node: Node,material: Material):
	if node is MeshInstance3D:node.material_override=material
	for child in node.get_children():ghost_material(child,material)
func process():
	if w.client and active:active=false;cancel();root.get_parent().hide();u.apply_view_layout()
	if active and not move_uid.is_empty():
		var old=u.board.terrain.get_node_or_null("Prop_"+move_uid)
		if old:old.hide()
func handle(event: InputEvent) -> bool:
	if not active:return false
	if event is InputEventMouseMotion:
		var next=u.board.cell_at(event.position)
		if next!=hover:hover=next;update_ghost()
		u.board.overlay.queue_redraw();return false
	if not event is InputEventMouseButton:return false
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:cancel();mode="Select";refresh();return true
	if event.button_index!=MOUSE_BUTTON_LEFT or event.shift_pressed:return false
	var cell=u.board.cell_at(event.position)
	if not u.board.valid_cell(cell):return true
	if mode=="Select":return true
	if event.pressed:
		if mode in ["Move","Duplicate","Eyedropper","Delete"]:
			var prop=w.builder.object_at(cell)
			if mode=="Delete":w.command("build_edit",{"op":"delete","uid":str(prop.get("uid","")),"x":cell.x,"y":cell.y});return true
			if not prop.is_empty():
				var operation=mode;choose(prop.asset);rotation=prop.rotation;swatch=prop.swatch
				if operation=="Move":move_uid=prop.uid
				mode="Place";refresh();hover=cell;update_ghost();return true
			if mode=="Eyedropper":choose(str(w.scene().get("surfaces",{}).get(str(cell.x)+","+str(cell.y),{0:"grass",1:"stone",2:"wood",3:"wall",4:"water",6:"door"}.get(int(w.scene().tiles.get(str(cell.x)+","+str(cell.y),0)),"stone"))))
			return true
		if mode in ["Raise","Lower"]:w.command("build_edit",{"op":"height","x":cell.x,"y":cell.y,"feet":w.encounter.elevation(cell)+step*(1 if mode=="Raise" else -1)});return true
		if mode=="Place":
			w.command("build_edit",{"op":"move" if not move_uid.is_empty() else "place","asset":asset,"uid":move_uid,"x":cell.x,"y":cell.y,"rotation":rotation,"swatch":swatch});cancel();return true
		start=cell;return true
	if start.x>=0:
		w.command("build_edit",{"op":"room" if mode=="Room" else "line" if mode=="Line" else "fill" if mode=="Fill" else "area","asset":asset,"x":start.x,"y":start.y,"ex":cell.x if mode!="Single" else start.x,"ey":cell.y if mode!="Single" else start.y});start=Vector2i(-1,-1)
	return true
func draw_preview():
	if not active or mode=="Select" or hover.x<0 or not u.board.valid_cell(hover):return
	var d=B.definition(asset);var valid=w.builder.assessment(asset,hover,rotation,move_uid)
	if is_instance_valid(info):info.text=valid.reason+" · "+mode+" · R rotates · Right-click cancels"
	if start.x>=0 and mode=="Line":
		var cursor=start
		while true:
			u.board.draw_cell(cursor,Color(.8,.7,.4,.12),Color("d9bf82"))
			if cursor==hover:break
			if cursor.x!=hover.x:cursor.x+=signi(hover.x-cursor.x)
			else:cursor.y+=signi(hover.y-cursor.y)
		return
	if start.x>=0 and mode=="Single":u.board.draw_cell(start,Color(.8,.7,.4,.12),Color("d9bf82"));return
	if start.x>=0:
		var left=mini(start.x,hover.x);var top=mini(start.y,hover.y);var right=maxi(start.x,hover.x);var bottom=maxi(start.y,hover.y)
		for x in range(left,right+1):
			for y in range(top,bottom+1):
				if mode!="Room" or x in [left,right] or y in [top,bottom]:u.board.draw_cell(Vector2i(x,y),Color(.8,.7,.4,.12),Color("d9bf82"))
	else:
		var size=Vector2i.ONE if mode in ["Raise","Lower","Delete","Eyedropper","Move","Duplicate"] else B.footprint(d,rotation)
		for x in size.x:
			for y in size.y:u.board.draw_cell(hover+Vector2i(x,y),Color(.4,.8,.6,.22) if valid.ok else Color(1,.3,.3,.25),Color("a4d5ae") if valid.ok else Color("f0958d"))
func templates():
	var body=u.modal("Create a new themed scene",760,620);u.paragraph(body,"Creates a separate editable scene. Your current map stays in the library.")
	for name in ["Throne hall","Volcanic crossing","Tidal ruins","Woodland camp","Frozen pass"]:u.button(body,name,func():w.command("build_edit",{"op":"template","theme":name});u.close_modal();u.board.fit_map())
