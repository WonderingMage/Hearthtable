extends SceneTree
var app
var w
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
	if ok:passed+=1;print("PASS "+text)
	else:failed+=1;push_error("FAIL "+text)
func frames():
	await process_frame;await process_frame;await process_frame
func find_button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=find_button(child,title)
		if found:return found
	return null
func run():
	await process_frame;w=root.get_node("World");w.reset_starter();w.command("encounter_settings",{"enabled":false})
	app=load("res://main.tscn").instantiate();root.add_child(app);await create_timer(.5).timeout;app.close_modal();root.size=Vector2i(1600,1000);await frames()
	var before=w.data.actors.size();app.show_creator();await frames();var c=app.creator
	check(c.tabs.get_tab_count()==7 and app.modal_tag=="character_creator","Creator offers Identity, Attributes, Skills, Equipment, Magic, Miniature and Review")
	check(w.data.actors.size()==before and c.submit.disabled,"Opening creator keeps a separate unconfirmed draft")
	c.fields.name.text="Seren of the Ash";c.fields.name.text_changed.emit(c.fields.name.text)
	c.fields.background.text="Knight of a fallen order";c.fields.background.text_changed.emit(c.fields.background.text)
	c.fields.STR.value=18;c.fields.hp.value=28;c.fields.max_hp.value=28;c.fields.level.value=3
	c.tabs.current_tab=5;await frames()
	c.fields.color_armor.color=Color("6a87a4");c.fields.color_armor.color_changed.emit(c.fields.color_armor.color)
	c.fields.mini_style.select(1);c.fields.mini_style.item_selected.emit(1)
	c.fields.mini_weapon.select(2);c.fields.mini_weapon.item_selected.emit(2);c.fields.mini_shield.select(5);c.fields.mini_shield.item_selected.emit(5);await frames()
	check(is_instance_valid(c.preview_figure) and c.preview_figure.get_node("Figure").get_child_count()>0,"Creator renders an actual live 3D miniature")
	check(c.preview_figure.find_child("Spike_Shield",true,false).visible and not c.preview_figure.find_child("Round_Shield",true,false).visible,"Preview switches actual equipment meshes through the appearance controls")
	c.fields.mini_style.select(4);c.fields.mini_style.item_selected.emit(4);c.fields.mini_shield.select(1);c.fields.mini_shield.item_selected.emit(1);await frames()
	check(not c.preview_figure.find_child("Barbarian_Round_Shield",true,false).visible,"Barbarian shield prop can be hidden independently of its body meshes")
	c.fields.mini_style.select(1);c.fields.mini_style.item_selected.emit(1);c.fields.mini_weapon.select(2);c.fields.mini_weapon.item_selected.emit(2);c.fields.mini_shield.select(5);c.fields.mini_shield.item_selected.emit(5);await frames()
	root.get_texture().get_image().save_png("user://creator_miniature.png")
	c.tabs.current_tab=6;await frames();check(c.review_text.text.contains("Seren of the Ash") and c.review_text.text.contains("STR 18") and c.review_text.text.contains("Knight of a fallen order"),"Review summarizes the edited identity and mechanical values")
	c.reviewed.button_pressed=true;c.fields.STR.value=17;check(not c.reviewed.button_pressed and c.submit.disabled,"Changing reviewed sheet values requires verification again")
	c.reviewed.button_pressed=true;c.submit.pressed.emit();await frames()
	var hero=w.actor(w.selected)
	check(w.data.actors.size()==before+1 and hero.name=="Seren of the Ash" and hero.abilities[0]==17 and hero.level==3,"Confirmed creator adds the edited hero")
	check(hero.background=="Knight of a fallen order" and hero.appearance.armor=="#6a87a4" and hero.appearance.shield=="Spike_Shield","Identity and miniature choices persist in actor data")
	check(app.board.actors.has(hero.id) and w.valid_campaign(w.data),"Created hero has a valid board miniature and campaign save")
	var hp=hero.hp;var ac=hero.ac;var abilities=hero.abilities.duplicate();var old_color=hero.appearance.armor
	c.customize(hero.id);await frames();c.fields.color_armor.color=Color("334455");c.fields.color_armor.color_changed.emit(c.fields.color_armor.color);app.close_modal();await frames()
	check(hero.appearance.armor==old_color,"Canceling customization leaves the real miniature unchanged")
	c.customize(hero.id);await frames();c.fields.color_armor.color=Color("aa5544");c.fields.color_armor.color_changed.emit(c.fields.color_armor.color);c.submit.pressed.emit();await frames()
	check(hero.appearance.armor=="#aa5544" and hero.hp==hp and hero.ac==ac and hero.abilities==abilities,"Saved cosmetic changes cannot change HP, AC or abilities")
	check(app.board.actors[hero.id].get_meta("signature").contains("#aa5544"),"Changing appearance rebuilds the real board figure")
	var path="user://creator-roundtrip.json";check(w.save_campaign(path)==OK and w.load_campaign(path),"Customized hero saves and reloads through ordinary campaign serialization")
	hero=w.actor(hero.id);check(hero.appearance.armor=="#aa5544" and hero.background=="Knight of a fallen order","Appearance and identity survive save/load")
	var result=load("res://scripts/beyond_import.gd").from_fields({"CharacterName":"Imported Sage","CLASS LEVEL":"Wizard 3","RACE":"Elf","BACKGROUND":"Sage","ALIGNMENT":"Neutral Good","STR":"8","DEX":"14","CON":"13","INT":"17","WIS":"12","CHA":"10","MaxHP":"19","AC":"12","Speed":"30","Total":"3d6","Arcana":"9","spellName0":"Magic Missile","spellPrepared0":"yes"},app.loadouts)
	app.show_character_import(result);await frames()
	check(c.draft.background=="Sage" and c.draft.alignment=="Neutral Good" and c.draft.skill_bonuses.Arcana==9,"Imported identity and final bonuses populate the same menu")
	check(c.draft.known_spells.size()==1 and c.draft.known_spells[0].name=="Magic Missile","Import review keeps the sheet's spell list without adding starter spells")
	c.tabs.current_tab=6;c.reviewed.button_pressed=true;c.submit.pressed.emit();await frames()
	check(w.actor(w.selected).known_spells.size()==1 and w.actor(w.selected).skill_bonuses.Arcana==9,"Confirmed import preserves exact spell selections and imported bonuses")
	app.show_creator();await frames();root.size=Vector2i(1200,760);await frames();app.show_creator();await frames()
	check(app.modal_overlay.get_global_rect().end.x<=root.size.x and c.tabs.size.x>500,"Creator remains within the minimum supported window")
	check(c.submit.get_global_rect().end.y<root.size.y and c.submit.get_global_rect().position.y>0,"Creation and cancel controls stay visible at the minimum window")
	root.get_texture().get_image().save_png("user://creator_minimum.png");app.close_modal()
	hero=w.actor(w.selected);app.character_ui.combat_actions(hero.id);await frames()
	check(find_button(app.modal_overlay,"Perform action")!=null,"Full-sheet combat action dialog is reachable")
	app.close_modal();app.board.set_view("Tactical");app.battle_ui.actor_id=hero.id;app.battle_ui.choose_action("Grapple");await frames()
	check(app.board.targeting and app.battle_ui.selected_kind=="action","Grapple hotbar enters creature targeting")
	app.battle_ui.cancel_selection();check(not app.board.targeting,"Canceling special actions restores movement")
	print("CREATOR_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
