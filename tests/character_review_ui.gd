extends SceneTree
var app
var w
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,title: String):
	if ok:passed+=1;print("PASS "+title)
	else:failed+=1;push_error("FAIL "+title)
func frames():await process_frame;await process_frame;await process_frame
func button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=button(child,title)
		if found:return found
	return null
func collect(node: Node,title: String,out: Array):
	if node is Button and node.text==title:out.append(node)
	for child in node.get_children():collect(child,title,out)
func shot(title: String):root.get_texture().get_image().save_png("user://"+title+".png")
func run():
	await process_frame;w=root.get_node("World");w.command("new_campaign",{"heroes":false,"title":"A new chronicle"})
	app=load("res://main.tscn").instantiate();root.add_child(app);root.size=Vector2i(1600,1000);await create_timer(.5).timeout;app.close_modal();await frames()
	check(button(app,"+ Create hero")==null,"The desktop offers PDF import instead of new-character creation")
	var result=preload("res://scripts/beyond_import.gd").from_fields({"CharacterName":"Aster Moonfall","CLASS LEVEL":"Wizard 3","RACE":"Astral Elf","BACKGROUND":"Planar Traveler","STR":"8","DEX":"14","CON":"13","INT":"17","WIS":"12","CHA":"10","MaxHP":"19","AC":"12","Speed":"30","Arcana":"9","Eq Name0":"Moonstone focus","Eq Qty0":"1","spellName0":"Magic Missile","spellPrepared0":"yes","ProficienciesLang":"Common, Elvish","AdditionalNotes1":"A promise to the moon."},app.loadouts)
	app.show_character_import(result);await frames();var c=app.creator;var saved=c.draft.duplicate(true)
	check(is_instance_valid(c.preview_figure) and c.tabs.get_tab_count()==6,"PDF import immediately shows the live miniature and full sheet sections")
	check(c.fields.race.get_item_text(c.fields.race.selected)=="Astral Elf" and c.fields.background.get_item_text(c.fields.background.selected)=="Planar Traveler","Non-catalog imported identity choices remain selected")
	check(c.draft.skill_bonuses.Arcana==9 and c.fields.skill_bonus_Arcana.value==9,"The full training sheet displays the imported final bonus")
	for i in 6:c.tabs.current_tab=i;await frames()
	check(c.draft.abilities==saved.abilities and c.draft.hp==saved.hp and c.draft.ac==saved.ac and c.draft.known_spells==saved.known_spells,"Reviewing all sections preserves final scores, health, armor and spells")
	c.tabs.current_tab=2;await frames();var equipped=button(c.item_rows,"Equipped");var attuned=button(c.item_rows,"Attuned")
	check(equipped!=null and attuned!=null and not equipped.button_pressed,"Imported equipment exposes explicit equipped and attuned states")
	equipped.button_pressed=true;attuned.button_pressed=true
	check(c.draft.inventory_items[0].equipped and c.draft.inventory_items[0].attuned,"Equipment review edits the isolated draft")
	shot("review_equipment");c.tabs.current_tab=3;await frames()
	var prepared=button(c.spell_rows,"Prepared");check(prepared!=null,"The imported spellbook exposes its preparation choice")
	prepared.button_pressed=false;await frames();check(not c.draft.known_spells[0].prepared,"Spell preparation changes the review draft without casting or spending slots")
	shot("review_spells");check(c.submit.disabled,"Unreviewed sheets cannot be submitted")
	c.reviewed.button_pressed=true;c.fields.name.text="Aster Dawnfall";c.fields.name.text_changed.emit("Aster Dawnfall")
	check(not c.reviewed.button_pressed and c.submit.disabled,"An edit invalidates the previous review confirmation")
	c.reviewed.button_pressed=true;c.submit.pressed.emit();await frames();var hero=w.actor(w.selected)
	check(w.data.actors.size()==1 and hero.name=="Aster Dawnfall" and hero.inventory_items[0].equipped and hero.inventory_items[0].attuned and not hero.known_spells[0].prepared,"Confirmation persists the reviewed gear and spell choices")
	check(hero.abilities==saved.abilities and hero.skill_bonuses.Arcana==9 and w.valid_campaign(w.data),"Confirmed import retains its final mechanics in a valid campaign")
	app.creator.customize(hero.id);await frames();var hp=hero.hp;var ac=hero.ac;c.fields.color_armor.color=Color("69418f");c.fields.color_armor.color_changed.emit(c.fields.color_armor.color);c.submit.pressed.emit();await frames()
	check(hero.appearance.armor=="#69418f" and hero.hp==hp and hero.ac==ac,"Miniature customization saves appearance without changing the character sheet")
	app.show_character_import(result);await frames();button(app.modal_overlay,"Cancel import").pressed.emit();await frames();check(w.data.actors.size()==1,"Cancel discards the imported draft")
	root.size=Vector2i(1200,760);await frames();app.toast("Synthetic review notice");app.show_character_import(result);await frames()
	check(c.submit.get_global_rect().end.y<=760 and c.tabs.get_global_rect().end.x<=1200,"Import review sections and persistent approval controls fit the minimum window")
	check(app.notice_panel.get_global_rect().end.y<c.submit.get_global_rect().position.y and app.notice_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Notifications reserve space above the sheet and cannot cover or intercept approval")
	shot("review_minimum");app.close_modal();root.size=Vector2i(1600,1000);await frames()
	for shape in ["Circle","Cone","Square"]:w.command("template",{"shape":shape,"x":5,"y":5,"ex":9,"ey":9})
	app.set_tool("Erase area");await frames();var point=app.board.project(Vector3(7,.06,7));check(app.board.template_at(point)==2,"The board eraser selects the newest overlapping spell area")
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=point;app.board._gui_input(click);await frames();check(w.scene().areas.size()==2,"The actual board eraser deletes a spell template")
	w.undo();check(w.scene().areas.size()==3,"Undo restores an erased template")
	app.show_area_templates();await frames();button(app.modal_overlay,"Clear all spell areas").pressed.emit();await frames();check(w.scene().areas.is_empty(),"Area management clears all spell shapes")
	app.close_modal();var count=w.data.scenes.size();app.show_prepared_maps();await frames();var matches=[];collect(app.modal_overlay,"Add to scene library",matches);matches[1].pressed.emit();await frames()
	check(w.data.scenes.size()==count+1 and w.data.scenes[-1].height==46 and not w.data.scenes[-1].image.is_empty(),"The actual throne button imports the complete embedded map through its small catalog request")
	app.close_modal();print("CHARACTER_REVIEW_UI_RESULT "+str(passed)+" passed, "+str(failed)+" failed");quit(1 if failed else 0)
