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
func find_button(node: Node,text: String):
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found:return found
	return null
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.command("new_campaign",{"heroes":false})
	var loadouts=w.read_json("res://assets/loadouts.json",{});var a=loadouts.Fighter.duplicate(true);a.id="fighter";a.name="Rowan Ashford";a.scene=w.data.scene;a.x=4;a.y=7
	var b=loadouts.Wizard.duplicate(true);b.id="mage";b.name="Liora Moss";b.scene=w.data.scene;b.x=6;b.y=7
	var foe=loadouts.Fighter.duplicate(true);foe.hero=false;foe.id="foe";foe.name="Orc sentinel";foe.race="humanoid";foe.class="Monster";foe.scene=w.data.scene;foe.x=4;foe.y=5;foe.color="#dca781";foe.hp=80;foe.max_hp=80
	w.data.actors=[a,b,foe];w.command("resize",{"width":16,"height":12})
	for x in range(1,15):w.command("tile",{"x":x,"y":1,"tile":3});w.command("tile",{"x":x,"y":10,"tile":3})
	for y in range(2,10):w.command("tile",{"x":1,"y":y,"tile":3});w.command("tile",{"x":14,"y":y,"tile":3})
	for y in range(2,10):w.command("tile",{"x":8,"y":y,"tile":3})
	w.command("tile",{"x":8,"y":6,"tile":6});w.command("tile",{"x":2,"y":3,"tile":7});w.command("tile",{"x":7,"y":3,"tile":7});w.command("tile",{"x":3,"y":3,"tile":8});w.command("tile",{"x":10,"y":4,"tile":13})
	w.command("elevation",{"x":11,"y":4,"feet":5});w.selected=a.id;w.mark_changed()
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(2560,1440)
	await create_timer(0.5).timeout;app.close_modal();app.board.set_view("First person");app.battle_ui.actor_id=a.id;app.battle_ui.target_id=foe.id
	await frames();app.battle_ui.refresh();await frames()
	check(app.board.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"First-person camera uses perspective projection")
	check(not app.board.actors[a.id].visible,"First-person view hides own miniature")
	check(absf(app.board.camera.position.y-1.105)<0.1,"Camera sits at the character’s eye height")
	check(app.immersion_panels.all(func(p):return not p.visible),"Immersive layout hides DM editing sidebars")
	check(app.battle_ui.root.get_parent().visible,"Player action dock is visible")
	check(find_button(app.battle_ui.root,"Attack")!=null,"Action dock exposes targeting and attack resolution")
	root.get_texture().get_image().save_png("user://first_person.png")
	w.command("initiative");w.data.combat.order=[a.id,foe.id,b.id];w.data.combat.turn=0;a.action=false;w.command("move",{"id":a.id,"x":4,"y":6});await create_timer(0.25).timeout;app.battle_ui.refresh();await frames()
	var attack=find_button(app.battle_ui.root,"Attack");check(attack!=null and not attack.disabled,"Moving into range enables the action-card attack")
	attack.pressed.emit();await frames();check(a.action and w.data.resolutions.any(func(e):return e.kind=="attack"),"Action-card confirmation publishes an authoritative attack outcome")
	root.get_texture().get_image().save_png("user://combat_outcome.png")
	w.command("end_combat");w.selected=b.id;app.battle_ui.actor_id=b.id;app.battle_ui.category="Cantrips";app.battle_ui.selected_kind="spell";app.battle_ui.selected_key="firebolt";app.battle_ui.slot=0;app.battle_ui.components=true;app.battle_ui.pick_target(foe.id);await frames()
	var cast_button=find_button(app.battle_ui.root,"Cast");check(cast_button!=null and not cast_button.disabled,"Cantrip card provides a legal target-and-cast action")
	var before_slots=int(b.slots[0]);cast_button.pressed.emit();await frames();check(b.slots[0]==before_slots and w.data.resolutions.any(func(e):return e.kind=="attack" and e.title=="Fire Bolt"),"Casting from a cantrip card publishes its roll without spending a slot")
	app.battle_ui.category="Spells";app.battle_ui.selected_key="magicmissile";app.battle_ui.slot=1;app.battle_ui.refresh();await frames()
	cast_button=find_button(app.battle_ui.root,"Cast");check(cast_button!=null and not cast_button.disabled,"Leveled spell card allocates all darts to its target")
	cast_button.pressed.emit();await frames();check(b.slots[0]==before_slots-1,"Leveled spell card ticks the chosen slot off")
	app.battle_ui.selected_key="shield";app.battle_ui.refresh();await frames();find_button(app.battle_ui.root,"Cast").pressed.emit();await frames();check(w.encounter.effective_ac(b)==int(b.ac)+5,"Self-targeted reaction card applies Shield automatically")
	b.level=5;b.hp=500;b.max_hp=500;a.hp=500;a.max_hp=500;b.slots[2]=1;b.slots_max[2]=1;w.command("learn_spell",{"id":b.id,"spell":"fireball"});w.command("prepare_spell",{"id":b.id,"spell":"fireball"})
	app.battle_ui.selected_key="fireball";app.battle_ui.slot=3;app.battle_ui.origin=Vector2i(4,2);app.battle_ui.area_confirmed=true;app.battle_ui.refresh();await frames()
	check(not app.board.spell_preview.is_empty() and app.board.spell_preview.targets.has(foe.id),"Area spell card builds a shared ground preview and target list")
	root.get_texture().get_image().save_png("user://spell_preview.png")
	cast_button=find_button(app.battle_ui.root,"Cast");check(cast_button!=null and not cast_button.disabled,"Confirmed area spell can cast from the dock")
	cast_button.pressed.emit();await frames();check(b.slots[2]==0 and w.data.resolutions.any(func(e):return e.kind=="save" and e.title=="Fireball"),"Area card applies authoritative target saves and slot spending")
	app.board.set_view("Following");await frames();check(app.board.actors[a.id].visible,"Following camera restores own hero model")
	root.get_texture().get_image().save_png("user://following.png")
	var saved=app.board.camera.position;app.board.pov_yaw=1.0;await frames();check(app.board.camera.position.distance_to(saved)>0.2,"Following camera orbits hero")
	app.board.set_view("Diorama");await frames();check(app.board.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"DM overhead view is preserved")
	check(app.immersion_panels.all(func(p):return p.visible),"DM panels return after leaving the player camera")
	app.show_3d_settings();await frames();check(find_button(app.modal_overlay,"Apply scene & combat settings")!=null and app.board.input_locked,"3D setup opens and locks movement input")
	app.close_modal();check(not app.board.input_locked,"Closing a dialog restores game input")
	w.client=true;a.owner=1;app.board.set_view("Diorama");await frames();check(app.board.camera_mode=="Tactical","Joined players cannot select DM overhead camera")
	w.client=false;app.board.set_view("Diorama");app.close_modal()
	check(w.valid_campaign(w.data),"3D scene data and new actor state serialize safely")
	print("IMMERSIVE_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+ProjectSettings.globalize_path("user://"));quit(1 if failed else 0)
