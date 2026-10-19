extends RefCounted
var u
var w
var drawing=false
var show_zones=false
var start=Vector2i(-1,-1)
var hover=Vector2i(-1,-1)
var zone_name="Battle room"
var intro="The room falls silent. Roll for initiative."
func _init(app,world):u=app;w=world
func open():
	if w.client:return
	drawing=false;start=Vector2i(-1,-1)
	var body=u.modal("Battle zones · DM only",800,750)
	u.paragraph(body,"Draw a hidden boundary around a battle room. A hero crossing into an armed zone stops at its edge and starts initiative with your encounter introduction. Zones fire once until rearmed. Zone outlines and coordinates are never sent to players.",u.INK,15)
	var auto=CheckBox.new();auto.text="Automatic initiative for attacks, proximity and battle zones";auto.button_pressed=w.director.enabled();body.add_child(auto)
	var row=u.row(body);row.add_child(u.label("Hostile alert distance · feet (0 disables proximity)"));var radius=u.number(row,int(w.data.get("automation",{}).get("proximity_ft",15)),0,120)
	u.button(body,"Apply encounter triggers",func():w.command("encounter_settings",{"enabled":auto.button_pressed,"radius":radius.value}),"Distance uses map scale and clear sight lines")
	var shown=CheckBox.new();shown.text="Show private zone outlines on the DM map";shown.button_pressed=show_zones;body.add_child(shown);shown.toggled.connect(func(value):show_zones=value;u.board.overlay.queue_redraw())
	u.heading(body,"DRAW A NEW BOUNDARY")
	var title=u.line(body,"Encounter name shown when triggered",zone_name);var text=TextEdit.new();text.text=intro;text.custom_minimum_size.y=70;text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.add_child(text)
	u.button(body,"Draw battle zone on map",func():
		zone_name=title.text.left(100);intro=text.text.left(600);u.close_modal()
		if u.build_editor.active:u.build_editor.toggle()
		u.battle_ui.enemy_mode=false;u.battle_ui.refresh();u.set_tool("Select");show_zones=true;drawing=true;u.toast("Drag a rectangle around the battle room. Right-click or Escape cancels."),"Click and drag opposite corners; the boundary stays private",true)
	for zone in w.scene().get("battle_zones",[]):
		var panel=u.panel(body);u.paragraph(panel,zone.name+" · "+("Disabled" if not zone.enabled else "Spent" if zone.spent else "Armed")+" · "+str(zone.w)+" × "+str(zone.h)+" squares",u.GOLD)
		var tools=u.row(panel)
		u.button(tools,"Disable" if zone.enabled else "Enable",func():w.command("battle_zone",{"op":"toggle","id":zone.id});open())
		u.button(tools,"Rearm",func():w.command("battle_zone",{"op":"rearm","id":zone.id});open())
		u.button(tools,"Edit",func():edit(zone))
		u.button(tools,"Delete",func():w.command("battle_zone",{"op":"delete","id":zone.id});open())
func edit(zone: Dictionary):
	var body=u.modal("Edit battle room",650,430);var title=u.line(body,"Encounter title",zone.name);var text=TextEdit.new();text.text=zone.intro;text.custom_minimum_size.y=120;body.add_child(text)
	u.button(body,"Save",func():w.command("battle_zone",{"op":"edit","id":zone.id,"name":title.text,"intro":text.text});open(),"",true)
func cancel():drawing=false;start=Vector2i(-1,-1);u.board.overlay.queue_redraw()
func handle(event: InputEvent) -> bool:
	if not drawing or w.client:return false
	if event is InputEventMouseMotion:hover=u.board.cell_at(event.position);u.board.overlay.queue_redraw();return true
	if not event is InputEventMouseButton:return false
	if event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:cancel();return true
	if event.button_index!=MOUSE_BUTTON_LEFT or event.shift_pressed:return false
	var cell=u.board.cell_at(event.position)
	if not u.board.valid_cell(cell):return true
	if event.pressed:start=cell
	elif start.x>=0:
		w.command("battle_zone",{"op":"add","x":start.x,"y":start.y,"ex":cell.x,"ey":cell.y,"name":zone_name,"intro":intro});cancel();u.toast("Hidden battle boundary added. Review or rearm it in Battle zones.")
	return true
func outline(x: int,y: int,width: int,height: int,title: String,color: Color):
	var points=PackedVector2Array()
	for point in [Vector3(x,.06,y),Vector3(x+width,.06,y),Vector3(x+width,.06,y+height),Vector3(x,.06,y+height)]:points.append(u.board.project(point))
	u.board.overlay.draw_colored_polygon(points,Color(color,.08));points.append(points[0]);u.board.overlay.draw_polyline(points,color,2,true);u.board.draw_text(points[0]+Vector2(0,-7),title,12,color)
func draw():
	if w.client or w.preview:return
	if show_zones:
		for zone in w.scene().get("battle_zones",[]):outline(zone.x,zone.y,zone.w,zone.h,zone.name+" · "+("SPENT" if zone.spent else "ARMED" if zone.enabled else "OFF"),Color("d4a0eb") if zone.enabled and not zone.spent else Color("727583"))
	if drawing and start.x>=0 and hover.x>=0:outline(mini(start.x,hover.x),mini(start.y,hover.y),absi(start.x-hover.x)+1,absi(start.y-hover.y)+1,"New battle boundary",Color("f4cd87"))
