extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,note: String):
	if ok:passed+=1;print("PASS "+note)
	else:failed+=1;push_error("FAIL "+note)
func frames():
	await process_frame;await process_frame;await process_frame
func button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=button(child,title)
		if found:return found
	return null
func illustrated_cards(node: Node) -> Array:
	var result=[]
	if node is Button and node.get_script()!=null and node.get_script().resource_path=="res://scripts/gilded_card.gd":result.append(node)
	for child in node.get_children():result.append_array(illustrated_cards(child))
	return result
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.command("new_campaign",{"heroes":false})
	var loadouts=w.read_json("res://assets/loadouts.json",{});var a=loadouts.Fighter.duplicate(true);a.id="fighter";a.name="Rowan Ashford";a.scene=w.data.scene;a.x=4;a.y=7
	var mage=loadouts.Wizard.duplicate(true);mage.id="mage";mage.name="Liora Moss";mage.scene=w.data.scene;mage.x=5;mage.y=8
	var foe=loadouts.Fighter.duplicate(true);foe.hero=false;foe.id="foe";foe.name="Orc sentinel";foe.class="Monster";foe.scene=w.data.scene;foe.x=7;foe.y=7;foe.hp=100;foe.max_hp=100
	w.data.actors=[a,mage,foe];w.command("resize",{"width":16,"height":12})
	for x in range(1,15):w.command("tile",{"x":x,"y":1,"tile":3});w.command("tile",{"x":x,"y":10,"tile":3})
	for y in range(2,10):w.command("tile",{"x":1,"y":y,"tile":3});w.command("tile",{"x":14,"y":y,"tile":3})
	w.command("tile",{"x":9,"y":6,"tile":3});w.command("tile",{"x":9,"y":7,"tile":6});w.command("tile",{"x":3,"y":3,"tile":7});w.command("tile",{"x":11,"y":3,"tile":7});w.selected=a.id;w.mark_changed()
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000)
	await create_timer(0.5).timeout;app.close_modal();app.board.set_view("Tactical");await frames()
	var board=app.board;var dock=app.battle_ui;var hud=dock.tactical_hud
	check(board.camera_mode=="Tactical" and board.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Tactical player camera uses 3D perspective")
	check(board.actors[a.id].visible,"Tactical camera displays the controlled 3D hero")
	check(hud.visible and not dock.root.get_parent().visible,"Tactical HUD replaces the large card dock")
	check(app.immersion_panels.all(func(p):return not p.visible),"Tactical play hides DM editor panels")
	check(button(hud,"End turn  ›")!=null and button(hud,"Actions")!=null,"HUD contains action categories and End turn")
	check(dock.selected_kind=="move" and not board.targeting,"Tactical view starts in click-to-move mode")
	var illustrated=illustrated_cards(hud)
	check(illustrated.size()>=5 and illustrated.all(func(card):return card.artwork.texture!=null and card.artwork.texture.get_width()==256),"Hotbar uses full-resolution dedicated artwork on every action slot")
	check(hud.bottom.get_theme_stylebox("panel") is StyleBoxTexture and app.theme.get_stylebox("normal","Button") is StyleBoxTexture,"HUD and global controls use textured gilded materials")
	var click=InputEventMouseButton.new();click.position=illustrated[0].get_global_rect().get_center();click.global_position=click.position;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;Input.parse_input_event(click);await frames();click=click.duplicate();click.pressed=false;Input.parse_input_event(click);await frames()
	check(dock.selected_kind=="weapon" and board.targeting,"Clicking through the illustrated slot arms its actual weapon action")
	dock.cancel_selection();await frames()
	var actor_cell=Vector2i(a.x,a.y);var old_focus=board.tactical_focus
	board.pan_tactical(Vector2(1,0));await frames()
	check(board.tactical_focus.distance_to(old_focus)>0.5 and Vector2i(a.x,a.y)==actor_cell,"Camera panning does not move the character")
	check(not board.tactical_tracking,"Panning releases character-follow mode")
	board.focus_selected();await create_timer(0.15).timeout;check(board.tactical_tracking,"Center restores smooth hero tracking")
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;var distance=board.tactical_distance;board.tactical_input(wheel)
	check(board.tactical_distance<distance,"Mouse wheel zooms the tactical camera")
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_MIDDLE;press.pressed=true;board.tactical_input(press)
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(50,0);var yaw=board.tactical_yaw;board.tactical_input(motion);press.pressed=false;board.tactical_input(press)
	check(absf(yaw-board.tactical_yaw)>0.2,"Middle-drag rotates the 3D scene")
	var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_O;board._unhandled_key_input(key);check(board.tactical_top,"O toggles a tactical overhead angle")
	board._unhandled_key_input(key);board.update_camera();board.hover_actor_id="";board.update_movement_preview(Vector2i(6,7))
	check(board.movement_preview.ok and board.movement_preview.cost==10,"Hover previews a legal route with its exact 5e cost")
	check(board.movement_preview.path.size()==2,"Route preview includes each traversed square")
	w.command("initiative");w.data.combat.order=[a.id,foe.id,mage.id];w.data.combat.turn=0;a.moved=25;board.movement_signature="";board.update_movement_preview(Vector2i(6,7))
	check(not board.movement_preview.ok and board.movement_preview.path.size()==2,"Over-budget preview keeps the route but reports rejection")
	dock.pick_ground(Vector2i(6,7));check(a.x==4 and a.moved==25,"Click-to-move refuses an over-budget destination")
	w.command("combat_action",{"id":a.id,"action":"Dash"});board.movement_signature="";board.update_movement_preview(Vector2i(6,7));check(board.movement_preview.ok,"Dash immediately increases the legal path budget")
	dock.pick_ground(Vector2i(6,7));await frames();check(a.x==6 and a.moved==35,"Click movement commits the routed cost through authoritative rules")
	w.encounter.reset_turn(a);a.action=false;a.moved=0;dock.choose_weapon(0);await frames();var hp=foe.hp
	check(board.targeting and dock.selected_kind=="weapon","Weapon hotbar enters targeting mode")
	board.tactical_hovered.emit(foe.id);await frames();check(foe.hp==hp and not a.action,"Hovering an enemy previews without attacking")
	check(dock.selection_preview.ok and str(dock.selection_preview.reason).contains("%"),"Target preview provides a legal hit percentage")
	dock.pick_target(foe.id);await frames();check(a.action and w.data.resolutions.any(func(e):return e.kind=="attack"),"Clicking a legal armed target resolves the attack")
	check(not board.targeting and dock.selected_kind=="move","Resolving an attack returns to safe movement mode")
	w.command("end_combat");w.selected=mage.id;board.pov_actor_id=mage.id;dock.actor_id=mage.id;await frames();dock.category="Cantrips";dock.choose_spell("firebolt");dock.pick_target(foe.id);await frames()
	check(not dock.selection_preview.ok and not mage.action,"Spell casting waits for component confirmation")
	dock.components=true;dock.refresh();await frames();var slots=int(mage.slots[0]);dock.pick_target(foe.id);await frames()
	check(mage.slots[0]==slots and w.data.resolutions.any(func(e):return e.title=="Fire Bolt"),"Confirmed cantrip target click resolves without spending a slot")
	dock.category="Spells";dock.choose_spell("magicmissile");dock.components=true;dock.refresh();dock.pick_target(foe.id);await frames()
	check(mage.slots[0]==slots-1,"Spell hotbar ticks off the selected slot")
	root.size=Vector2i(1200,760);await frames();hud.refresh();await frames()
	check(hud.bottom.size.x<=board.size.x and hud.bottom.position.y>=0,"HUD fits the minimum supported window width")
	check(hud.bottom.size.y<board.size.y*0.6,"Compact hotbar preserves the majority of the 3D world")
	check(hud.party.position.y+hud.party.size.y<hud.bottom.position.y,"Party portraits do not overlap the hotbar at minimum resolution")
	dock.choose_spell("magicmissile");dock.components=true;dock.refresh();await frames()
	check(hud.bottom.size.x<=board.size.x,"Spell targeting controls fit the minimum supported width")
	dock.cancel_selection();await frames()
	root.get_texture().get_image().save_png("user://tactical_minimum.png")
	root.size=Vector2i(2560,1440);board.focus_selected();await create_timer(0.3).timeout;dock.category="Actions";dock.cancel_selection();await frames();root.get_texture().get_image().save_png("user://tactical_exploration.png")
	w.selected=a.id;dock.actor_id=a.id;board.pov_actor_id=a.id;board.focus_selected();w.command("initiative");w.data.combat.order=[a.id,foe.id,mage.id];w.data.combat.turn=0;a.action=false;a.moved=0;dock.choose_weapon(0);board.tactical_hovered.emit(foe.id);await frames();root.get_texture().get_image().save_png("user://tactical_combat.png")
	board.set_view("Diorama");await frames();check(board.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and not hud.visible,"DM board restores its orthographic controls")
	check(app.immersion_panels.all(func(p):return p.visible),"DM editor panels return after tactical play")
	w.client=true;a.owner=1;board.set_view("Diorama");await frames();check(board.camera_mode=="Tactical","Joined players default to the tactical camera")
	w.client=false;board.set_view("Diorama");app.close_modal();check(w.valid_campaign(w.data),"Tactical play preserves campaign serialization")
	print("TACTICAL_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+ProjectSettings.globalize_path("user://"));quit(1 if failed else 0)
