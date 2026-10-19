extends SceneTree
var w
var app
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(value: bool,description: String):
	if value:passed+=1;print("PASS "+description)
	else:failed+=1;push_error("FAIL "+description)
func frames():
	await process_frame
	await process_frame
	await process_frame
func find_text(node: Node,text: String):
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=find_text(child,text)
		if found:return found
	return null
func all_spins(node: Node) -> Array:
	var result=[]
	if node is SpinBox:result.append(node)
	for child in node.get_children():result.append_array(all_spins(child))
	return result
func run():
	await process_frame;w=root.get_node("World");w.reset_starter()
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(2560,1440)
	await create_timer(1).timeout;app.close_modal();await frames()
	var mage=w.data.actors.filter(func(a):return a.class=="Wizard")[0]
	# Keep initiative deterministic while exercising the real opening-cast flow.
	mage.initiative_bonus=100
	w.selected=mage.id;app.character_ui.show_book(mage.id);await frames()
	check(app.modal_tag=="spellbook" and find_text(app.modal_overlay,"+ Add spell")!=null,"Spellbook opens with add and casting controls")
	root.get_texture().get_image().save_png("user://spellbook.png")
	app.character_ui.add_spell(mage);await frames();check(find_text(app.modal_overlay,"+ Add")!=null,"Illustrated spell catalogue opens with usable add controls")
	find_text(app.modal_overlay,"+ Add").pressed.emit();await frames();check(mage.known_spells.size()>0,"Illustrated catalogue add action remains functional")
	app.character_ui.show_book(mage.id);await frames()
	app.character_ui.cast_dialog(mage.id,"magicmissile");await frames()
	check(find_text(app.modal_overlay,"Cast & spend slot")!=null,"Casting dialog exposes targets, slots and cast action")
	root.get_texture().get_image().save_png("user://cast.png")
	find_text(app.modal_overlay,"Cast & spend slot").pressed.emit();await frames()
	check(is_instance_valid(app.modal_overlay),"Invalid cast stays open for correction")
	var before_slots=int(mage.slots[0]);var target=w.data.actors[4];var before_hp=int(target.hp);var spins=all_spins(app.modal_overlay)
	spins[4].value=3;find_text(app.modal_overlay,"I have the required components; DM confirms costs / reaction trigger").button_pressed=true
	find_text(app.modal_overlay,"Cast & spend slot").pressed.emit();await frames()
	check(w.data.combat.active and mage.slots[0]==before_slots and target.hp==before_hp,"Opening hostile cast rolls initiative without spending a slot or damaging its target")
	check(w.encounter.is_turn(mage),"The fixture's initiative modifier gives the caster the first turn")
	app.character_ui.cast_dialog(mage.id,"magicmissile");await frames()
	spins=all_spins(app.modal_overlay);spins[4].value=3;find_text(app.modal_overlay,"I have the required components; DM confirms costs / reaction trigger").button_pressed=true
	find_text(app.modal_overlay,"Cast & spend slot").pressed.emit();await frames()
	check(mage.slots[0]==before_slots-1 and target.hp<before_hp and not is_instance_valid(app.modal_overlay),"Confirming the cast on the caster's turn spends one slot, deals damage and returns to the table")
	for page in ["Overview","Skills","Equipment","Features"]:
		app.character_ui.full_sheet(mage.id,page);await frames();check(is_instance_valid(app.modal_overlay),"Full sheet page opens: "+page)
		if page=="Overview":root.get_texture().get_image().save_png("user://character_sheet.png")
	app.character_ui.item_editor(mage,-1);await frames();check(find_text(app.modal_overlay,"Save item")!=null,"Structured equipment editor opens")
	app.character_ui.coins(mage);await frames();check(find_text(app.modal_overlay,"Save purse")!=null,"Coin purse editor opens")
	app.character_ui.read_spell(mage,w.spell_lookup.magicmissile);await frames();check(find_text(app.modal_overlay,"Innate / feature uses…")!=null,"DM can configure per-spell innate charges")

	app.character_ui.custom_spell(mage,{});await frames();check(find_text(app.modal_overlay,"Save custom spell")!=null,"DM custom spell editor opens")
	app.character_ui.feature_editor(mage,-1);await frames();check(find_text(app.modal_overlay,"Save feature")!=null,"Feature counter editor opens")
	app.character_ui.notes(mage);await frames();check(find_text(app.modal_overlay,"Save sheet notes")!=null,"Player notes/equipment editor opens")
	app.show_scene_library();await frames();check(find_text(app.modal_overlay,"Import battlemap image…")!=null,"Scene library offers image import")
	root.get_texture().get_image().save_png("user://scenes.png")
	var image=Image.create(800,600,false,Image.FORMAT_RGB8);image.fill(Color("355069"));image.save_png("user://test_map.png")
	var count=w.data.scenes.size();var active=w.data.scene;app.import_scene_image(ProjectSettings.globalize_path("user://test_map.png"));await frames()
	find_text(app.modal_overlay,"Add to scene library").pressed.emit();await frames()
	check(w.data.scenes.size()==count+1 and w.data.scene==active,"Image import adds a new scene without replacing active scene")
	var scene=w.data.scenes[-1];check(scene.name=="test_map" and not scene.image.is_empty(),"Imported scene retains image and chosen name")
	check(w.SCENE_FILES.save(w,scene.id,"user://roundtrip.hearthscene")==OK,"Scene package exports")
	var package=w.read_json("user://roundtrip.hearthscene",{});w.command("import_scene",{"package":package});await frames()
	check(w.data.scenes.size()==count+2 and w.data.scenes[-1].id!=scene.id,"Scene package import generates a distinct reusable scene")
	var bad=package.duplicate(true);bad.scene.width=1000;w.command("import_scene",{"package":bad});check(w.data.scenes.size()==count+2,"Invalid scene dimensions are rejected")
	w.command("duplicate_scene",{"scene":scene.id});check(w.data.scenes.size()==count+3,"Scene duplication works")
	w.command("delete_scene",{"scene":w.data.scenes[-1].id});check(w.data.scenes.size()==count+2,"Inactive scene can be deleted")
	w.command("delete_scene",{"scene":active});check(w.data.scenes.size()==count+2,"Active scene cannot be deleted")
	app.show_session();await frames();check(find_text(app.modal_overlay,"Host this campaign · open lobby")!=null,"Session offers configurable hosting and join")
	check(w.host_session("test",24711,true)==OK,"Custom UDP port can host a lobby")
	app.show_session();await frames();check(find_text(app.modal_overlay,"Start table →")!=null,"Host sees DM lobby controls")
	root.get_texture().get_image().save_png("user://lobby.png")
	find_text(app.modal_overlay,"Start table →").pressed.emit();await frames();check(w.session.phase=="table","DM can start the table")
	w.disconnect_session();app.close_modal()
	print("FEATURE_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed · "+ProjectSettings.globalize_path("user://"));quit(1 if failed else 0)
